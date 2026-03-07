# Caching and Redis (Node.js)

## ioredis Setup

```bash
pnpm add ioredis
pnpm add -D @types/node
```

### Connection with Reconnect Strategy

```typescript
// redis.client.ts
import Redis from 'ioredis'

const redis = new Redis({
  host: process.env.REDIS_HOST ?? 'localhost',
  port: Number(process.env.REDIS_PORT) || 6379,
  password: process.env.REDIS_PASSWORD,
  db: 0,

  // Connection pooling via lazyConnect + cluster, or just configure maxRetriesPerRequest
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  lazyConnect: false,

  retryStrategy(times) {
    if (times > 10) return null // Stop retrying after 10 attempts
    return Math.min(times * 100, 3000) // Exponential backoff, max 3s
  },
})

redis.on('connect', () => console.log('Redis connected'))
redis.on('error', (err) => console.error('Redis error:', err))
redis.on('reconnecting', () => console.log('Redis reconnecting...'))

export { redis }
```

---

## CacheService Implementation

```typescript
// cache.service.ts
import { redis } from './redis.client'

export class CacheService {
  private defaultTtl = 3600 // 1 hour

  async get<T>(key: string): Promise<T | null> {
    const value = await redis.get(key)
    if (value === null) return null
    try {
      return JSON.parse(value) as T
    } catch {
      return value as unknown as T
    }
  }

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    const serialized = JSON.stringify(value)
    const ttl = ttlSeconds ?? this.defaultTtl
    await redis.setex(key, ttl, serialized)
  }

  async del(key: string): Promise<void> {
    await redis.del(key)
  }

  async exists(key: string): Promise<boolean> {
    return (await redis.exists(key)) === 1
  }

  async ttl(key: string): Promise<number> {
    return redis.ttl(key)
  }

  // Invalidate all keys matching a glob pattern (use with caution on large datasets)
  async invalidatePattern(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern)
    if (keys.length === 0) return

    // Use pipeline for batch deletes
    const pipeline = redis.pipeline()
    keys.forEach((key) => pipeline.del(key))
    await pipeline.exec()
  }

  // Atomic get-or-set (prevents cache stampede)
  async getOrSet<T>(
    key: string,
    factory: () => Promise<T>,
    ttlSeconds?: number
  ): Promise<T> {
    const cached = await this.get<T>(key)
    if (cached !== null) return cached

    const value = await factory()
    await this.set(key, value, ttlSeconds)
    return value
  }
}

export const cacheService = new CacheService()
```

Usage:
```typescript
// In a service
async getUser(id: string): Promise<User> {
  return cacheService.getOrSet(
    `user:${id}`,
    () => this.userRepository.findById(id),
    300 // 5 minutes
  )
}
```

---

## Pipeline for Batch Operations

```typescript
// Batch multiple operations in a single round-trip
async function getUserBatch(ids: string[]): Promise<(User | null)[]> {
  const pipeline = redis.pipeline()
  ids.forEach((id) => pipeline.get(`user:${id}`))

  const results = await pipeline.exec()
  return results!.map(([err, value]) => {
    if (err || value === null) return null
    return JSON.parse(value as string) as User
  })
}

// Multi/exec for atomic transactions
async function transferCredits(fromId: string, toId: string, amount: number) {
  const result = await redis
    .multi()
    .decrby(`credits:${fromId}`, amount)
    .incrby(`credits:${toId}`, amount)
    .exec()

  if (!result) throw new Error('Transaction aborted')
  return result
}
```

---

## Common Redis Patterns

### SETEX / GET / DEL

```typescript
// String with TTL
await redis.setex('session:abc123', 900, JSON.stringify(sessionData)) // 15 min
await redis.get('session:abc123')
await redis.del('session:abc123')

// Increment counters
await redis.incr('page:views:home')
await redis.incrby('user:123:score', 10)

// Hash — store object fields separately
await redis.hset('user:123', { name: 'Alice', role: 'admin' })
await redis.hget('user:123', 'name')
await redis.hgetall('user:123')
await redis.expire('user:123', 3600)

// Lists — FIFO queue
await redis.lpush('queue:emails', JSON.stringify(emailJob))
const job = await redis.rpop('queue:emails')

// Sets — unique members
await redis.sadd('online:users', userId)
await redis.srem('online:users', userId)
await redis.sismember('online:users', userId)

// Sorted sets — leaderboards
await redis.zadd('leaderboard', score, userId)
await redis.zrevrange('leaderboard', 0, 9) // top 10
```

---

## @Cacheable Decorator

```typescript
// cacheable.decorator.ts
import { cacheService } from './cache.service'

interface CacheableOptions {
  ttl?: number
  keyPrefix?: string
}

export function Cacheable(options: CacheableOptions = {}) {
  return function (
    target: unknown,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value as (...args: unknown[]) => Promise<unknown>

    descriptor.value = async function (this: unknown, ...args: unknown[]) {
      const prefix = options.keyPrefix ?? `${target!.constructor.name}:${propertyKey}`
      const key = `${prefix}:${JSON.stringify(args)}`

      const cached = await cacheService.get(key)
      if (cached !== null) return cached

      const result = await originalMethod.apply(this, args)
      await cacheService.set(key, result, options.ttl)
      return result
    }

    return descriptor
  }
}

// Usage
class UserService {
  @Cacheable({ ttl: 300, keyPrefix: 'user' })
  async getUser(id: string): Promise<User> {
    return this.repo.findById(id)
  }

  @Cacheable({ ttl: 60 })
  async getUsersByRole(role: string): Promise<User[]> {
    return this.repo.findByRole(role)
  }
}
```

---

## Cache Invalidation Strategies

### TTL-Based (Simplest)

Set a TTL on every key and let them expire naturally. Works when slight staleness is acceptable.

```typescript
await redis.setex(`product:${id}`, 600, JSON.stringify(product)) // 10 min
```

### Event-Driven Invalidation

Invalidate cache keys when underlying data changes:

```typescript
// In UserService — invalidate after mutation
async updateUser(id: string, data: UpdateUserDTO): Promise<User> {
  const updated = await this.repo.update(id, data)
  await cacheService.del(`user:${id}`)               // exact key
  await cacheService.invalidatePattern(`users:list:*`) // related lists
  return updated
}
```

### Tag-Based Invalidation

Associate cache entries with tags; invalidate by tag:

```typescript
class TaggedCache {
  async setWithTags(key: string, value: unknown, tags: string[], ttl = 3600) {
    await redis.setex(key, ttl, JSON.stringify(value))
    // Store key in tag sets
    await Promise.all(tags.map((tag) => redis.sadd(`tag:${tag}`, key)))
  }

  async invalidateTag(tag: string) {
    const keys = await redis.smembers(`tag:${tag}`)
    if (keys.length === 0) return
    await redis.del(...keys, `tag:${tag}`)
  }
}

// Usage
await taggedCache.setWithTags(`user:${id}`, user, ['users', `user:${id}`])
// Invalidate all user-tagged entries
await taggedCache.invalidateTag('users')
```

### Write-Through vs Write-Behind

| Strategy | Description | Use When |
|----------|-------------|----------|
| **Write-through** | Update cache AND DB on every write (sync) | Reads are frequent, write latency acceptable |
| **Write-behind** | Update cache immediately, DB async via queue | Write-heavy, eventual consistency ok |
| **Cache-aside** | Read: check cache → DB → populate. Write: invalidate cache | Most common; simple, flexible |

---

## Pub/Sub Patterns

```typescript
// publisher.ts
async function publishEvent(channel: string, payload: unknown) {
  await redis.publish(channel, JSON.stringify(payload))
}

// subscriber.ts — use a SEPARATE Redis connection for subscribe
import Redis from 'ioredis'

const subscriber = new Redis({ /* same config */ })

subscriber.subscribe('user:events', (err, count) => {
  if (err) throw err
  console.log(`Subscribed to ${count} channel(s)`)
})

subscriber.on('message', (channel, message) => {
  const event = JSON.parse(message)
  console.log(`Event on ${channel}:`, event)
})

// Pattern subscribe
subscriber.psubscribe('cache:*')
subscriber.on('pmessage', (pattern, channel, message) => {
  // Handles all channels matching cache:*
})
```

---

## Redis Session Storage (Express)

```bash
pnpm add express-session connect-redis
```

```typescript
import session from 'express-session'
import RedisStore from 'connect-redis'
import { redis } from './redis.client'

app.use(
  session({
    store: new RedisStore({ client: redis, prefix: 'sess:' }),
    secret: process.env.SESSION_SECRET!,
    resave: false,
    saveUninitialized: false,
    cookie: {
      secure: process.env.NODE_ENV === 'production',
      httpOnly: true,
      maxAge: 1000 * 60 * 60 * 24, // 24 hours
      sameSite: 'lax',
    },
  })
)
```

---

## Testing with Fake Redis

Use `ioredis-mock` for unit tests:

```bash
pnpm add -D ioredis-mock
```

```typescript
// In test setup
vi.mock('ioredis', () => {
  const { default: RedisMock } = await import('ioredis-mock')
  return { default: RedisMock }
})
```

Or use `testcontainers` for integration tests against real Redis:
```typescript
import { GenericContainer } from 'testcontainers'

const redisContainer = await new GenericContainer('redis:7')
  .withExposedPorts(6379)
  .start()

const redis = new Redis({
  host: redisContainer.getHost(),
  port: redisContainer.getMappedPort(6379),
})
```
