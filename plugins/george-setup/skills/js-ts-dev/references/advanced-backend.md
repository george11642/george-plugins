# Advanced Backend Patterns - Full Reference

WebSockets, BullMQ job queues, GraphQL, microservices, request cancellation, message queues. See node-backend.md for Express/Fastify basics.

## WebSocket with Socket.io

```typescript
import { Server } from 'socket.io';
import { createServer } from 'http';
import express from 'express';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: process.env.CLIENT_URL, credentials: true },
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Middleware — authenticate on connection
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!);
    socket.data.userId = (payload as any).userId;
    next();
  } catch {
    next(new Error('Unauthorized'));
  }
});

// Connection handling
io.on('connection', (socket) => {
  const { userId } = socket.data;
  console.log(`User ${userId} connected: ${socket.id}`);

  // Join user to their personal room (for targeted messages)
  socket.join(`user:${userId}`);

  // Join a chat room
  socket.on('room:join', (roomId: string) => {
    socket.join(`room:${roomId}`);
    // Notify others in room
    socket.to(`room:${roomId}`).emit('user:joined', { userId, socketId: socket.id });
  });

  socket.on('room:leave', (roomId: string) => {
    socket.leave(`room:${roomId}`);
    socket.to(`room:${roomId}`).emit('user:left', { userId });
  });

  // Chat message
  socket.on('message:send', async (data: { roomId: string; text: string }) => {
    const message = await saveMessage({ userId, ...data });
    // Broadcast to everyone in room including sender
    io.to(`room:${data.roomId}`).emit('message:new', message);
  });

  socket.on('disconnect', (reason) => {
    console.log(`User ${userId} disconnected: ${reason}`);
  });
});

// Send targeted notification from anywhere in your app
export function notifyUser(userId: string, event: string, data: unknown) {
  io.to(`user:${userId}`).emit(event, data);
}

// Broadcast to all users in a room
export function broadcastToRoom(roomId: string, event: string, data: unknown) {
  io.to(`room:${roomId}`).emit(event, data);
}

httpServer.listen(3000);

// Client-side (browser or Node)
import { io as socketClient } from 'socket.io-client';

const socket = socketClient('http://localhost:3000', {
  auth: { token: localStorage.getItem('token') },
  reconnection: true,
  reconnectionAttempts: 5,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
});

socket.on('connect', () => console.log('Connected:', socket.id));
socket.on('connect_error', (err) => console.error('Connection failed:', err.message));
socket.on('disconnect', (reason) => {
  if (reason === 'io server disconnect') socket.connect(); // manual reconnect
});

socket.emit('room:join', 'general');
socket.on('message:new', (msg) => displayMessage(msg));
```

## BullMQ Job Queues

```typescript
import { Queue, Worker, QueueEvents, Job } from 'bullmq';
import IORedis from 'ioredis';

const connection = new IORedis({
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT ?? '6379'),
  maxRetriesPerRequest: null,  // required for BullMQ
});

// Define job type interfaces
interface EmailJob {
  to: string;
  subject: string;
  template: string;
  data: Record<string, unknown>;
}

interface ImageJob {
  imageUrl: string;
  userId: string;
  sizes: number[];
}

// Create queue
export const emailQueue = new Queue<EmailJob>('email', { connection });
export const imageQueue = new Queue<ImageJob>('image-processing', { connection });

// Add jobs
await emailQueue.add('welcome', {
  to: 'user@example.com',
  subject: 'Welcome!',
  template: 'welcome',
  data: { name: 'Alice' },
});

// Delayed job
await emailQueue.add('follow-up', jobData, {
  delay: 24 * 60 * 60 * 1000, // 24 hours
});

// Repeating job (cron)
await emailQueue.add('digest', {}, {
  repeat: { pattern: '0 9 * * *' }, // 9am daily
  jobId: 'daily-digest',             // stable ID prevents duplicates
});

// Job with retry strategy
await imageQueue.add('resize', jobData, {
  attempts: 5,
  backoff: {
    type: 'exponential',
    delay: 2000,  // 2s, 4s, 8s, 16s, 32s
  },
});

// Worker — processes jobs
const emailWorker = new Worker<EmailJob>(
  'email',
  async (job: Job<EmailJob>) => {
    const { to, subject, template, data } = job.data;

    // Update progress
    await job.updateProgress(10);

    const html = await renderTemplate(template, data);
    await job.updateProgress(50);

    await sendEmail({ to, subject, html });
    await job.updateProgress(100);

    return { sent: true, at: new Date().toISOString() };
  },
  {
    connection,
    concurrency: 10,        // process up to 10 jobs simultaneously
    removeOnComplete: { count: 1000 },
    removeOnFail: { count: 5000 },
  },
);

// Worker event handlers
emailWorker.on('completed', (job, result) => {
  console.log(`Job ${job.id} completed:`, result);
});

emailWorker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed:`, err.message);
});

emailWorker.on('progress', (job, progress) => {
  console.log(`Job ${job.id} progress: ${progress}%`);
});

// Queue events — monitor from outside the worker
const queueEvents = new QueueEvents('email', { connection });
queueEvents.on('waiting', ({ jobId }) => console.log(`Job ${jobId} waiting`));
queueEvents.on('active', ({ jobId }) => console.log(`Job ${jobId} active`));
queueEvents.on('stalled', ({ jobId }) => console.log(`Job ${jobId} stalled`));

// Graceful shutdown
async function shutdown() {
  await emailWorker.close();
  await emailQueue.close();
  connection.disconnect();
}
process.on('SIGTERM', shutdown);
```

## GraphQL Schema + Resolvers + DataLoader

```typescript
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import DataLoader from 'dataloader';

// Schema definition (SDL)
const typeDefs = `#graphql
  type User {
    id: ID!
    name: String!
    email: String!
    posts: [Post!]!
    createdAt: String!
  }

  type Post {
    id: ID!
    title: String!
    body: String!
    author: User!
    tags: [String!]!
  }

  input CreatePostInput {
    title: String!
    body: String!
    tags: [String!]
  }

  type Query {
    user(id: ID!): User
    users(limit: Int = 20, offset: Int = 0): [User!]!
    post(id: ID!): Post
    posts(authorId: ID, tag: String): [Post!]!
  }

  type Mutation {
    createPost(input: CreatePostInput!): Post!
    deletePost(id: ID!): Boolean!
  }

  type Subscription {
    postCreated: Post!
  }
`;

// DataLoader — batch and cache to solve N+1
// Without DataLoader: 1 query for posts + N queries for each author
// With DataLoader: 1 query for posts + 1 batch query for all authors
function createUserLoader(db: Pool) {
  return new DataLoader<string, User>(async (userIds) => {
    const { rows } = await db.query(
      'SELECT * FROM users WHERE id = ANY($1)',
      [userIds],
    );
    // IMPORTANT: must return results in same order as input keys
    const usersById = new Map(rows.map(u => [u.id, u]));
    return userIds.map(id => usersById.get(id) ?? new Error(`User ${id} not found`));
  });
}

// Context — created per request
interface Context {
  userId: string | null;
  loaders: { users: DataLoader<string, User> };
  db: Pool;
}

// Resolvers
const resolvers = {
  Query: {
    user: async (_: unknown, { id }: { id: string }, ctx: Context) => {
      return ctx.loaders.users.load(id);  // batched automatically
    },
    users: async (_: unknown, { limit, offset }: { limit: number; offset: number }, ctx: Context) => {
      const { rows } = await ctx.db.query('SELECT * FROM users LIMIT $1 OFFSET $2', [limit, offset]);
      return rows;
    },
    posts: async (_: unknown, args: { authorId?: string; tag?: string }, ctx: Context) => {
      let query = 'SELECT * FROM posts WHERE 1=1';
      const params: unknown[] = [];
      if (args.authorId) { query += ` AND author_id = $${params.push(args.authorId)}`; }
      if (args.tag) { query += ` AND $${params.push(args.tag)} = ANY(tags)`; }
      const { rows } = await ctx.db.query(query, params);
      return rows;
    },
  },

  Mutation: {
    createPost: async (_: unknown, { input }: { input: CreatePostInput }, ctx: Context) => {
      if (!ctx.userId) throw new GraphQLError('Not authenticated', { extensions: { code: 'UNAUTHORIZED' } });
      const { rows } = await ctx.db.query(
        'INSERT INTO posts (title, body, author_id, tags) VALUES ($1,$2,$3,$4) RETURNING *',
        [input.title, input.body, ctx.userId, input.tags ?? []],
      );
      return rows[0];
    },
  },

  // Field resolvers — resolve nested fields
  User: {
    posts: async (user: User, _: unknown, ctx: Context) => {
      const { rows } = await ctx.db.query('SELECT * FROM posts WHERE author_id = $1', [user.id]);
      return rows;
    },
  },

  Post: {
    // DataLoader call — batches all author lookups for a list of posts into 1 SQL query
    author: (post: Post, _: unknown, ctx: Context) => {
      return ctx.loaders.users.load(post.authorId);
    },
  },
};

const server = new ApolloServer<Context>({ typeDefs, resolvers });

const { url } = await startStandaloneServer(server, {
  context: async ({ req }) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    const userId = token ? verifyToken(token) : null;
    return {
      userId,
      db: pool,
      loaders: { users: createUserLoader(pool) },  // new loader per request (clears cache)
    };
  },
});

// Depth/complexity limiting (prevent abusive queries)
import depthLimit from 'graphql-depth-limit';
import { createComplexityLimitRule } from 'graphql-validation-complexity';

const server = new ApolloServer<Context>({
  typeDefs,
  resolvers,
  validationRules: [
    depthLimit(7),
    createComplexityLimitRule(1000),
  ],
});
```

## Microservice Patterns

```typescript
// Service-to-service HTTP with circuit breaker
class ServiceClient {
  private failureCount = 0;
  private lastFailureTime = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  private readonly threshold = 5;
  private readonly timeout = 30_000; // 30s

  constructor(private baseUrl: string, private serviceName: string) {}

  private isOpen() {
    if (this.state === 'open' && Date.now() - this.lastFailureTime > this.timeout) {
      this.state = 'half-open';
    }
    return this.state === 'open';
  }

  async request<T>(path: string, options?: RequestInit): Promise<T> {
    if (this.isOpen()) {
      throw new Error(`Circuit breaker open for ${this.serviceName}`);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 5000);

    try {
      const res = await fetch(`${this.baseUrl}${path}`, {
        ...options,
        signal: controller.signal,
        headers: { 'Content-Type': 'application/json', ...options?.headers },
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      this.failureCount = 0;
      this.state = 'closed';
      return res.json();
    } catch (err) {
      this.failureCount++;
      this.lastFailureTime = Date.now();
      if (this.failureCount >= this.threshold) this.state = 'open';
      throw err;
    } finally {
      clearTimeout(timer);
    }
  }
}

// Event-driven pattern with typed events
import EventEmitter from 'eventemitter3';

interface AppEvents {
  'user.created': { userId: string; email: string };
  'order.placed': { orderId: string; userId: string; total: number };
  'payment.failed': { orderId: string; reason: string };
}

class AppEventBus extends EventEmitter<AppEvents> {}
export const eventBus = new AppEventBus();

// Publisher
eventBus.emit('user.created', { userId: '123', email: 'alice@example.com' });

// Subscriber
eventBus.on('user.created', async ({ userId, email }) => {
  await emailQueue.add('welcome', { to: email, template: 'welcome', data: { userId }, subject: 'Welcome!' });
});

// Idempotency key pattern — prevent duplicate processing
class IdempotencyService {
  constructor(private redis: Redis) {}

  async executeOnce<T>(key: string, ttlSeconds: number, fn: () => Promise<T>): Promise<T> {
    const cached = await this.redis.get(`idem:${key}`);
    if (cached) return JSON.parse(cached);

    const result = await fn();
    await this.redis.setex(`idem:${key}`, ttlSeconds, JSON.stringify(result));
    return result;
  }
}

// Usage: safe to call multiple times with same key
const result = await idempotency.executeOnce(
  `create-order:${requestId}`,
  3600,
  () => orderService.create(orderData),
);
```

## Request Cancellation with AbortController

```typescript
// Cancellable fetch with timeout
async function fetchWithTimeout<T>(url: string, options: RequestInit & { timeoutMs?: number } = {}): Promise<T> {
  const { timeoutMs = 5000, ...fetchOptions } = options;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(new Error(`Timeout after ${timeoutMs}ms`)), timeoutMs);

  try {
    const res = await fetch(url, { ...fetchOptions, signal: controller.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    return res.json();
  } catch (err) {
    if ((err as Error).name === 'AbortError') throw new Error(`Request timed out: ${url}`);
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

// Cancel multiple requests on user action (React pattern)
function useUserData(userId: string) {
  useEffect(() => {
    const controller = new AbortController();

    async function load() {
      try {
        const data = await fetch(`/api/users/${userId}`, { signal: controller.signal }).then(r => r.json());
        setUser(data);
      } catch (err) {
        if ((err as Error).name !== 'AbortError') setError(err as Error);
      }
    }

    load();
    return () => controller.abort();  // cancel on unmount or userId change
  }, [userId]);
}

// Node.js: propagate cancellation through service layers
async function getOrderWithDetails(orderId: string, signal: AbortSignal): Promise<OrderDetails> {
  signal.throwIfAborted();  // fail fast if already cancelled

  const [order, items] = await Promise.all([
    orderRepo.findById(orderId, signal),
    itemRepo.findByOrderId(orderId, signal),
  ]);

  signal.throwIfAborted();

  const productIds = items.map(i => i.productId);
  const products = await productService.fetchMany(productIds, { signal });

  return { order, items, products };
}

// Express route with cancellation
router.get('/api/orders/:id', async (req, res) => {
  const controller = new AbortController();
  req.on('close', () => controller.abort());  // cancel if client disconnects

  try {
    const order = await getOrderWithDetails(req.params.id, controller.signal);
    res.json(order);
  } catch (err) {
    if (controller.signal.aborted) return;  // client gone, don't send response
    next(err);
  }
});
```

## Message Queues

### RabbitMQ with amqplib

```typescript
import amqp from 'amqplib';

// Publisher
async function createPublisher() {
  const connection = await amqp.connect(process.env.RABBITMQ_URL!);
  const channel = await connection.createChannel();

  // Declare exchange (survives broker restart)
  await channel.assertExchange('events', 'topic', { durable: true });

  return {
    async publish(routingKey: string, data: unknown) {
      const payload = Buffer.from(JSON.stringify(data));
      channel.publish('events', routingKey, payload, {
        persistent: true,          // survive broker restart
        contentType: 'application/json',
        timestamp: Date.now(),
      });
    },
    async close() {
      await channel.close();
      await connection.close();
    },
  };
}

// Consumer
async function createConsumer(queueName: string, routingKey: string, handler: (data: unknown) => Promise<void>) {
  const connection = await amqp.connect(process.env.RABBITMQ_URL!);
  const channel = await connection.createChannel();

  await channel.assertExchange('events', 'topic', { durable: true });
  const { queue } = await channel.assertQueue(queueName, { durable: true });
  await channel.bindQueue(queue, 'events', routingKey);

  channel.prefetch(10);  // process up to 10 messages concurrently

  channel.consume(queue, async (msg) => {
    if (!msg) return;
    try {
      const data = JSON.parse(msg.content.toString());
      await handler(data);
      channel.ack(msg);  // acknowledge success
    } catch (err) {
      console.error('Processing failed:', err);
      // nack: requeue=false sends to dead letter queue
      channel.nack(msg, false, false);
    }
  });
}

// Usage
const publisher = await createPublisher();
await publisher.publish('user.created', { userId: '123', email: 'alice@x.com' });

await createConsumer('email-service', 'user.*', async (data) => {
  await sendWelcomeEmail(data);
});
```

### Kafka with kafkajs

```typescript
import { Kafka, CompressionTypes, logLevel } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'my-service',
  brokers: (process.env.KAFKA_BROKERS ?? 'localhost:9092').split(','),
  logLevel: logLevel.WARN,
});

// Producer
const producer = kafka.producer();
await producer.connect();

await producer.send({
  topic: 'user-events',
  compression: CompressionTypes.GZIP,
  messages: [
    {
      key: userId,                          // partition by userId for ordering
      value: JSON.stringify({ type: 'created', userId, email }),
      headers: { 'event-type': 'user.created', 'service': 'user-service' },
    },
  ],
});

// Consumer (within a consumer group — each partition assigned to one consumer)
const consumer = kafka.consumer({ groupId: 'email-service' });
await consumer.connect();
await consumer.subscribe({ topic: 'user-events', fromBeginning: false });

await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    const key = message.key?.toString();
    const value = JSON.parse(message.value!.toString());
    const eventType = message.headers?.['event-type']?.toString();

    console.log(`[${topic}] partition=${partition} key=${key} type=${eventType}`);

    if (eventType === 'user.created') {
      await sendWelcomeEmail(value);
    }
  },
});

// Graceful shutdown
async function shutdown() {
  await producer.disconnect();
  await consumer.disconnect();
}
process.on('SIGTERM', shutdown);
```
