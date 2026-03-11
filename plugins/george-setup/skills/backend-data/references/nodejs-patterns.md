# Node.js Backend Patterns

Production-ready patterns for Express.js and Fastify with TypeScript. Use this file for framework setup, architecture, middleware, error handling, database, and caching patterns.

---

## Express.js Setup

Complete production boilerplate with security, compression, and logging:

```typescript
// src/app.ts
import express, { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import { requestLogger } from './middleware/logger.middleware';
import { errorHandler } from './middleware/error-handler';
import { apiLimiter } from './middleware/rate-limit.middleware';
import userRoutes from './routes/user.routes';

const app = express();

// Security headers first
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') ?? [],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
}));
app.use(compression());

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging + rate limiting
app.use(requestLogger);
app.use('/api', apiLimiter);

// Routes
app.use('/api/v1/users', userRoutes);

// Health check (unauthenticated)
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

// Global error handler — must be last
app.use(errorHandler);

export { app };
```

```typescript
// src/server.ts
import { app } from './app';
import { pool, closeDatabase } from './config/database';

const PORT = Number(process.env.PORT) || 3000;

const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} [${process.env.NODE_ENV}]`);
});

// Graceful shutdown
const shutdown = async (signal: string) => {
  console.log(`${signal} received — shutting down`);
  server.close(async () => {
    await closeDatabase();
    process.exit(0);
  });
  // Force exit after 10s
  setTimeout(() => process.exit(1), 10_000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
```

---

## Fastify Setup

High-performance alternative with built-in schema validation.

### Fastify v5 Migration Notes
- Type providers split: use `validator` and `serializer` instead of single `output` type
- `withTypeProvider()` must be called within each plugin scope (not just root)
- Use `@fastify/type-provider-typebox` or `@fastify/type-provider-json-schema-to-ts`

```typescript
// Fastify v5 type provider setup
import Fastify from 'fastify'
import { TypeBoxTypeProvider } from '@fastify/type-provider-typebox'
import { Type } from 'typebox'

const server = Fastify().withTypeProvider<TypeBoxTypeProvider>()

// In plugins, call withTypeProvider again for scoped type safety
function myPlugin(fastify, _opts, done) {
  const typed = fastify.withTypeProvider<TypeBoxTypeProvider>()
  typed.get('/route', {
    schema: { querystring: Type.Object({ foo: Type.Number() }) }
  }, (req) => req.query.foo) // type-safe!
  done()
}
```

```typescript
// src/app.ts (Fastify)
import Fastify from 'fastify';
import helmet from '@fastify/helmet';
import cors from '@fastify/cors';
import compress from '@fastify/compress';
import rateLimit from '@fastify/rate-limit';
import Redis from 'ioredis';

const fastify = Fastify({
  logger: {
    level: process.env.LOG_LEVEL ?? 'info',
    transport: process.env.NODE_ENV !== 'production'
      ? { target: 'pino-pretty', options: { colorize: true } }
      : undefined,
  },
  trustProxy: true,
});

await fastify.register(helmet);
await fastify.register(cors, {
  origin: process.env.ALLOWED_ORIGINS?.split(',') ?? false,
  credentials: true,
});
await fastify.register(compress);
await fastify.register(rateLimit, {
  max: 100,
  timeWindow: '15 minutes',
  redis: new Redis({ host: process.env.REDIS_HOST, port: 6379 }),
  keyGenerator: (request) => request.ip,
  errorResponseBuilder: () => ({
    statusCode: 429,
    error: 'Too Many Requests',
    message: 'Rate limit exceeded. Retry after 15 minutes.',
  }),
});

// Type-safe route with schema validation
fastify.post<{
  Body: { name: string; email: string; password: string };
  Reply: { id: string; name: string; email: string };
}>(
  '/users',
  {
    schema: {
      body: {
        type: 'object',
        required: ['name', 'email', 'password'],
        properties: {
          name:     { type: 'string', minLength: 1, maxLength: 100 },
          email:    { type: 'string', format: 'email' },
          password: { type: 'string', minLength: 8 },
        },
        additionalProperties: false,
      },
      response: {
        201: {
          type: 'object',
          properties: {
            id:    { type: 'string' },
            name:  { type: 'string' },
            email: { type: 'string' },
          },
        },
      },
    },
  },
  async (request, reply) => {
    const user = await userService.createUser(request.body);
    reply.code(201).send(user);
  },
);

await fastify.listen({ port: 3000, host: '0.0.0.0' });
```

---

## Layered Architecture

```
src/
├── controllers/     # HTTP layer — parse request, call service, format response
├── services/        # Business logic — orchestrate repositories, enforce rules
├── repositories/    # Data access — SQL/ORM queries, no business logic
├── models/          # TypeScript interfaces and Zod schemas
├── middleware/      # Express/Fastify middleware
├── routes/          # Route wiring — connect middleware + controller
├── config/          # DB pool, Redis client, env validation
└── utils/           # errors.ts, response.ts, asyncHandler, etc.
```

### Controller Layer

```typescript
// src/controllers/user.controller.ts
import { Request, Response, NextFunction } from 'express';
import { UserService } from '../services/user.service';
import { CreateUserDTO, UpdateUserDTO } from '../models/user.model';
import { ApiResponse } from '../utils/response';
import { asyncHandler } from '../utils/asyncHandler';

export class UserController {
  constructor(private userService: UserService) {}

  createUser = asyncHandler(async (req: Request, res: Response) => {
    const dto: CreateUserDTO = req.body;
    const user = await this.userService.createUser(dto);
    ApiResponse.success(res, user, 'User created', 201);
  });

  getUser = asyncHandler(async (req: Request, res: Response) => {
    const user = await this.userService.getUserById(req.params.id);
    ApiResponse.success(res, user);
  });

  updateUser = asyncHandler(async (req: Request, res: Response) => {
    const dto: UpdateUserDTO = req.body;
    const user = await this.userService.updateUser(req.params.id, dto);
    ApiResponse.success(res, user);
  });

  deleteUser = asyncHandler(async (req: Request, res: Response) => {
    await this.userService.deleteUser(req.params.id);
    res.status(204).send();
  });

  listUsers = asyncHandler(async (req: Request, res: Response) => {
    const page  = Number(req.query.page)  || 1;
    const limit = Number(req.query.limit) || 20;
    const { data, total } = await this.userService.listUsers(page, limit);
    ApiResponse.paginated(res, data, page, limit, total);
  });
}
```

### Service Layer

```typescript
// src/services/user.service.ts
import bcrypt from 'bcrypt';
import { UserRepository } from '../repositories/user.repository';
import { CreateUserDTO, UpdateUserDTO, User } from '../models/user.model';
import { ConflictError, NotFoundError } from '../utils/errors';

export class UserService {
  constructor(private userRepository: UserRepository) {}

  async createUser(dto: CreateUserDTO): Promise<User> {
    const existing = await this.userRepository.findByEmail(dto.email);
    if (existing) throw new ConflictError('Email already registered');

    const hashedPassword = await bcrypt.hash(dto.password, 12);
    const user = await this.userRepository.create({ ...dto, password: hashedPassword });

    const { password: _pw, ...safe } = user;
    return safe as User;
  }

  async getUserById(id: string): Promise<User> {
    const user = await this.userRepository.findById(id);
    if (!user) throw new NotFoundError('User not found');
    const { password: _pw, ...safe } = user;
    return safe as User;
  }

  async updateUser(id: string, dto: UpdateUserDTO): Promise<User> {
    const updated = await this.userRepository.update(id, dto);
    if (!updated) throw new NotFoundError('User not found');
    const { password: _pw, ...safe } = updated;
    return safe as User;
  }

  async deleteUser(id: string): Promise<void> {
    const deleted = await this.userRepository.delete(id);
    if (!deleted) throw new NotFoundError('User not found');
  }

  async listUsers(page: number, limit: number) {
    const offset = (page - 1) * limit;
    return this.userRepository.findAll({ limit, offset });
  }
}
```

### Repository Layer

```typescript
// src/repositories/user.repository.ts
import { Pool } from 'pg';
import { CreateUserDTO, UpdateUserDTO, UserEntity } from '../models/user.model';

export class UserRepository {
  constructor(private db: Pool) {}

  async create(data: CreateUserDTO & { password: string }): Promise<UserEntity> {
    const { rows } = await this.db.query<UserEntity>(
      `INSERT INTO users (name, email, password)
       VALUES ($1, $2, $3)
       RETURNING id, name, email, password, created_at, updated_at`,
      [data.name, data.email, data.password],
    );
    return rows[0];
  }

  async findById(id: string): Promise<UserEntity | null> {
    const { rows } = await this.db.query<UserEntity>(
      'SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL',
      [id],
    );
    return rows[0] ?? null;
  }

  async findByEmail(email: string): Promise<UserEntity | null> {
    const { rows } = await this.db.query<UserEntity>(
      'SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL',
      [email],
    );
    return rows[0] ?? null;
  }

  async update(id: string, updates: UpdateUserDTO): Promise<UserEntity | null> {
    const keys = Object.keys(updates) as (keyof UpdateUserDTO)[];
    if (keys.length === 0) return this.findById(id);

    const setClause = keys.map((k, i) => `${k} = $${i + 2}`).join(', ');
    const values    = keys.map(k => updates[k]);

    const { rows } = await this.db.query<UserEntity>(
      `UPDATE users SET ${setClause}, updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING *`,
      [id, ...values],
    );
    return rows[0] ?? null;
  }

  async delete(id: string): Promise<boolean> {
    // Soft delete
    const { rowCount } = await this.db.query(
      'UPDATE users SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL',
      [id],
    );
    return (rowCount ?? 0) > 0;
  }

  async findAll({ limit, offset }: { limit: number; offset: number }) {
    const [{ rows: data }, { rows: [{ count }] }] = await Promise.all([
      this.db.query<UserEntity>(
        'SELECT id, name, email, created_at FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT $1 OFFSET $2',
        [limit, offset],
      ),
      this.db.query<{ count: string }>(
        'SELECT COUNT(*) FROM users WHERE deleted_at IS NULL',
      ),
    ]);
    return { data, total: Number(count) };
  }
}
```

---

## Dependency Injection Container

```typescript
// src/config/container.ts
import { Pool } from 'pg';
import { UserRepository } from '../repositories/user.repository';
import { UserService } from '../services/user.service';
import { UserController } from '../controllers/user.controller';
import { AuthService } from '../services/auth.service';
import { CacheService } from '../utils/cache';
import { createPool } from './database';

class Container {
  private readonly singletons = new Map<string, unknown>();
  private readonly factories   = new Map<string, () => unknown>();

  singleton<T>(key: string, factory: () => T): void {
    this.factories.set(key, () => {
      if (!this.singletons.has(key)) {
        this.singletons.set(key, factory());
      }
      return this.singletons.get(key) as T;
    });
  }

  register<T>(key: string, factory: () => T): void {
    this.factories.set(key, factory as () => unknown);
  }

  resolve<T>(key: string): T {
    const factory = this.factories.get(key);
    if (!factory) throw new Error(`Nothing registered for "${key}"`);
    return factory() as T;
  }
}

export const container = new Container();

// Infrastructure
container.singleton<Pool>('db', createPool);
container.singleton<CacheService>('cache', () => new CacheService());

// Repositories
container.singleton('userRepository', () =>
  new UserRepository(container.resolve('db')),
);

// Services
container.singleton('authService', () =>
  new AuthService(container.resolve('userRepository'), container.resolve('cache')),
);
container.singleton('userService', () =>
  new UserService(container.resolve('userRepository')),
);

// Controllers (transient — new instance per request group is fine)
container.register('userController', () =>
  new UserController(container.resolve('userService')),
);
```

---

## Middleware Patterns

### asyncHandler — Eliminate try/catch Boilerplate

```typescript
// src/utils/asyncHandler.ts
import { Request, Response, NextFunction } from 'express';

type AsyncRoute = (req: Request, res: Response, next: NextFunction) => Promise<unknown>;

export const asyncHandler = (fn: AsyncRoute) =>
  (req: Request, res: Response, next: NextFunction) =>
    Promise.resolve(fn(req, res, next)).catch(next);
```

### Zod Validation Middleware

```typescript
// src/middleware/validate.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { ValidationError } from '../utils/errors';

export const validate = (schema: AnyZodObject) =>
  async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const result = await schema.parseAsync({
        body:   req.body,
        query:  req.query,
        params: req.params,
      });
      // Overwrite with parsed/coerced values
      req.body   = result.body   ?? req.body;
      req.query  = result.query  ?? req.query;
      req.params = result.params ?? req.params;
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        const errors = err.errors.map(e => ({
          field:   e.path.join('.'),
          message: e.message,
          code:    e.code,
        }));
        next(new ValidationError('Validation failed', errors));
      } else {
        next(err);
      }
    }
  };

// Usage
import { z } from 'zod';
import { Router } from 'express';

const createUserSchema = z.object({
  body: z.object({
    name:     z.string().min(1).max(100).trim(),
    email:    z.string().email().toLowerCase(),
    password: z.string().min(8).max(128),
  }),
});

const router = Router();
router.post('/', validate(createUserSchema), userController.createUser);
```

### JWT Authentication Middleware

```typescript
// src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { UnauthorizedError, ForbiddenError } from '../utils/errors';

export interface JWTPayload {
  sub:   string;   // userId
  email: string;
  roles: string[];
  iat:   number;
  exp:   number;
}

declare global {
  namespace Express {
    interface Request {
      user?: JWTPayload;
    }
  }
}

export const authenticate = (req: Request, _res: Response, next: NextFunction) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return next(new UnauthorizedError('Missing or malformed Authorization header'));
  }

  const token = header.slice(7);
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET!) as JWTPayload;
    next();
  } catch (err) {
    next(new UnauthorizedError('Token invalid or expired'));
  }
};

export const requireRoles = (...roles: string[]) =>
  (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user) return next(new UnauthorizedError('Not authenticated'));
    const hasRole = roles.some(r => req.user!.roles.includes(r));
    if (!hasRole) return next(new ForbiddenError('Insufficient permissions'));
    next();
  };

// Usage
// router.delete('/:id', authenticate, requireRoles('admin'), controller.deleteUser);
```

### Redis-Backed Rate Limiting

```typescript
// src/middleware/rate-limit.middleware.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { redis } from '../config/redis';

const makeStore = (prefix: string) =>
  new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args), prefix });

// General API — 100 req / 15 min per IP
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:api:'),
  message: { status: 'error', message: 'Too many requests. Please try again later.' },
});

// Auth endpoints — 5 failed attempts / 15 min (skip successful)
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:'),
  message: { status: 'error', message: 'Too many failed attempts. Try again in 15 minutes.' },
});
```

### Request Logger Middleware

```typescript
// src/middleware/logger.middleware.ts
import { Request, Response, NextFunction } from 'express';
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
});

export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const start     = Date.now();
  const requestId = req.headers['x-request-id'] as string ?? crypto.randomUUID();
  req.headers['x-request-id'] = requestId;
  res.setHeader('x-request-id', requestId);

  res.on('finish', () => {
    logger.info({
      requestId,
      method:    req.method,
      path:      req.path,
      status:    res.statusCode,
      durationMs: Date.now() - start,
      ip:        req.ip,
      userAgent: req.headers['user-agent'],
    });
  });
  next();
};
```

---

## Custom Error Classes

```typescript
// src/utils/errors.ts
export class AppError extends Error {
  constructor(
    public readonly message:  string,
    public readonly statusCode: number = 500,
    public readonly code?:    string,
    public readonly isOperational = true,
  ) {
    super(message);
    this.name = this.constructor.name;
    Object.setPrototypeOf(this, new.target.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, public readonly errors?: Array<{ field: string; message: string; code?: string }>) {
    super(message, 400, 'VALIDATION_ERROR');
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Access denied') {
    super(message, 403, 'FORBIDDEN');
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, 'CONFLICT');
  }
}

export class TooManyRequestsError extends AppError {
  constructor(message = 'Rate limit exceeded') {
    super(message, 429, 'RATE_LIMITED');
  }
}
```

### Global Error Handler

```typescript
// src/middleware/error-handler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError, ValidationError } from '../utils/errors';
import { logger } from './logger.middleware';

export const errorHandler = (
  err:  Error,
  req:  Request,
  res:  Response,
  _next: NextFunction,
) => {
  if (err instanceof AppError) {
    const body: Record<string, unknown> = {
      status:  'error',
      code:    err.code ?? 'ERROR',
      message: err.message,
    };
    if (err instanceof ValidationError && err.errors) {
      body.errors = err.errors;
    }
    return res.status(err.statusCode).json(body);
  }

  // Unexpected / programming error
  logger.error({
    err:       err.message,
    stack:     err.stack,
    requestId: req.headers['x-request-id'],
    method:    req.method,
    path:      req.path,
  });

  res.status(500).json({
    status:  'error',
    code:    'INTERNAL_ERROR',
    message: process.env.NODE_ENV === 'production'
      ? 'An unexpected error occurred'
      : err.message,
  });
};
```

---

## ApiResponse Helper

```typescript
// src/utils/response.ts
import { Response } from 'express';

export class ApiResponse {
  static success<T>(res: Response, data: T, message?: string, statusCode = 200) {
    return res.status(statusCode).json({
      status: 'success',
      ...(message && { message }),
      data,
    });
  }

  static error(res: Response, message: string, statusCode = 500, code?: string) {
    return res.status(statusCode).json({ status: 'error', code, message });
  }

  static paginated<T>(
    res:    Response,
    data:   T[],
    page:   number,
    limit:  number,
    total:  number,
    meta?:  Record<string, unknown>,
  ) {
    return res.json({
      status: 'success',
      data,
      pagination: {
        page,
        limit,
        total,
        pages:    Math.ceil(total / limit),
        hasNext:  page * limit < total,
        hasPrev:  page > 1,
      },
      ...(meta && { meta }),
    });
  }
}
```

---

## Database Connection Pooling (PostgreSQL)

```typescript
// src/config/database.ts
import { Pool, PoolConfig } from 'pg';

export const createPool = (): Pool => {
  const config: PoolConfig = {
    host:                    process.env.DB_HOST,
    port:                    Number(process.env.DB_PORT ?? 5432),
    database:                process.env.DB_NAME,
    user:                    process.env.DB_USER,
    password:                process.env.DB_PASSWORD,
    ssl:                     process.env.DB_SSL === 'true' ? { rejectUnauthorized: true } : false,
    max:                     20,           // max pool size
    min:                     2,            // keep at least 2 connections alive
    idleTimeoutMillis:       30_000,       // close idle after 30s
    connectionTimeoutMillis: 3_000,        // fail fast if no connection available
    allowExitOnIdle:         true,         // let process exit cleanly in tests
  };

  const pool = new Pool(config);

  pool.on('connect', client => {
    // Set default statement timeout per connection
    client.query('SET statement_timeout = 30000');
  });

  pool.on('error', err => {
    console.error('Unexpected database pool error', err);
  });

  return pool;
};

export const closeDatabase = async (pool: Pool) => {
  await pool.end();
};
```

### Transaction Management

```typescript
// src/utils/transaction.ts
import { Pool, PoolClient } from 'pg';

export async function withTransaction<T>(
  pool: Pool,
  fn:   (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// Usage example — order with inventory update
export class OrderService {
  constructor(private db: Pool) {}

  async createOrder(userId: string, items: Array<{ productId: string; quantity: number; price: number }>) {
    return withTransaction(this.db, async (client) => {
      const total = items.reduce((sum, i) => sum + i.quantity * i.price, 0);

      const { rows: [order] } = await client.query(
        'INSERT INTO orders (user_id, total, status) VALUES ($1, $2, $3) RETURNING id',
        [userId, total, 'pending'],
      );

      for (const item of items) {
        await client.query(
          'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)',
          [order.id, item.productId, item.quantity, item.price],
        );

        const { rowCount } = await client.query(
          'UPDATE products SET stock = stock - $1 WHERE id = $2 AND stock >= $1',
          [item.quantity, item.productId],
        );
        if (!rowCount) throw new Error(`Insufficient stock for product ${item.productId}`);
      }

      return order.id as string;
    });
  }
}
```

---

## Redis Caching

```typescript
// src/config/redis.ts
import Redis from 'ioredis';

export const redis = new Redis({
  host:            process.env.REDIS_HOST ?? 'localhost',
  port:            Number(process.env.REDIS_PORT ?? 6379),
  password:        process.env.REDIS_PASSWORD,
  db:              Number(process.env.REDIS_DB ?? 0),
  maxRetriesPerRequest: 3,
  retryStrategy: (times) => Math.min(times * 100, 3_000),
  lazyConnect:     true,
});

redis.on('error', err => console.error('Redis error', err));
```

```typescript
// src/utils/cache.ts
import { redis } from '../config/redis';

export class CacheService {
  async get<T>(key: string): Promise<T | null> {
    const raw = await redis.get(key);
    return raw ? (JSON.parse(raw) as T) : null;
  }

  async set(key: string, value: unknown, ttlSeconds?: number): Promise<void> {
    const serialized = JSON.stringify(value);
    if (ttlSeconds) {
      await redis.setex(key, ttlSeconds, serialized);
    } else {
      await redis.set(key, serialized);
    }
  }

  async del(key: string): Promise<void> {
    await redis.del(key);
  }

  async invalidateByPattern(pattern: string): Promise<void> {
    // Use SCAN instead of KEYS — non-blocking for large keyspaces
    let cursor = '0';
    do {
      const [next, keys] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = next;
      if (keys.length) await redis.del(...keys);
    } while (cursor !== '0');
  }

  // Cache-aside helper: read-through with automatic population
  async getOrSet<T>(
    key:        string,
    fetcher:    () => Promise<T>,
    ttlSeconds: number,
  ): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null) return cached;

    const fresh = await fetcher();
    await this.set(key, fresh, ttlSeconds);
    return fresh;
  }
}

// @Cacheable decorator
export function Cacheable(ttlSeconds = 300, keyPrefix?: string) {
  return function (_target: object, propertyKey: string, descriptor: PropertyDescriptor) {
    const original = descriptor.value as (...args: unknown[]) => Promise<unknown>;
    descriptor.value = async function (...args: unknown[]) {
      const cache = new CacheService();
      const key   = `${keyPrefix ?? propertyKey}:${JSON.stringify(args)}`;
      const hit   = await cache.get(key);
      if (hit !== null) return hit;
      const result = await original.apply(this, args);
      await cache.set(key, result, ttlSeconds);
      return result;
    };
    return descriptor;
  };
}

// Usage:
// class ProductService {
//   @Cacheable(600, 'product')
//   async getProduct(id: string) { ... }
// }
```

---

## Route Wiring

```typescript
// src/routes/user.routes.ts
import { Router } from 'express';
import { z } from 'zod';
import { container } from '../config/container';
import { authenticate, requireRoles } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';
import { authLimiter } from '../middleware/rate-limit.middleware';
import type { UserController } from '../controllers/user.controller';

const router = Router();
const ctrl   = container.resolve<UserController>('userController');

const createSchema = z.object({
  body: z.object({
    name:     z.string().min(1).max(100).trim(),
    email:    z.string().email(),
    password: z.string().min(8),
  }),
});

const updateSchema = z.object({
  body: z.object({
    name:  z.string().min(1).max(100).trim().optional(),
    email: z.string().email().optional(),
  }),
  params: z.object({ id: z.string().uuid() }),
});

router.get   ('/',    authenticate, ctrl.listUsers);
router.post  ('/',    authLimiter, validate(createSchema), ctrl.createUser);
router.get   ('/:id', authenticate, ctrl.getUser);
router.patch ('/:id', authenticate, validate(updateSchema), ctrl.updateUser);
router.delete('/:id', authenticate, requireRoles('admin'), ctrl.deleteUser);

export default router;
```
