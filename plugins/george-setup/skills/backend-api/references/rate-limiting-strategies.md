# Rate Limiting Strategies Reference

## Algorithm Comparison

| Algorithm | Accuracy | Memory | Burst Handling | Complexity | Best For |
|-----------|----------|--------|----------------|------------|----------|
| Fixed Window | Low (edge burst) | O(1) | Allows 2x burst at boundary | Trivial | Simple counters, low-stakes |
| Sliding Window Log | Exact | O(n requests) | Precise | Medium | Strict per-user limits |
| Sliding Window Counter | ~95% accurate | O(1) | Smooth | Low | Most production APIs |
| Token Bucket | High | O(1) per key | Configurable burst | Medium | APIs with burst allowance |
| Leaky Bucket | High | O(queue size) | None — strict rate | High | Outbound request throttling |

### Fixed Window

```
Window: [0s ---- 60s] [60s ---- 120s]
         100 allowed    100 allowed
```

Weakness: at second 59, allow 100 requests. At second 61, allow 100 more. Burst of 200 in 2 seconds.

Redis implementation:
```
INCR user:123:2024110514    -- key = user:rate:YYYYMMDDHHmm
EXPIRE user:123:2024110514 60
```

### Sliding Window Log

Track exact timestamps in a sorted set. Most accurate, highest memory:

```
Each request → ZADD user:123:log NOW score=timestamp
Remove old → ZREMRANGEBYSCORE user:123:log 0 (now - window)
Count → ZCOUNT user:123:log (now - window) +inf
```

Memory: proportional to request volume (each request stores one entry).

### Sliding Window Counter (Recommended Default)

Hybrid approach: keep two fixed-window counters and interpolate:

```
Rate = prev_window_count * (1 - elapsed_fraction) + curr_window_count
```

~5% error vs exact sliding log. O(1) memory. Best balance for most APIs.

### Token Bucket

Tokens refill at a steady rate up to a maximum. Requests consume tokens. Allows bursts up to bucket capacity:

```
bucket_capacity = 100  (max burst)
refill_rate = 10/second
current_tokens = min(capacity, last_tokens + elapsed * refill_rate)
```

Characteristics:
- Smooth average rate enforcement
- Configurable burst headroom
- Request rejected instantly when bucket empty (no queue)

### Leaky Bucket

Requests enter a queue and are processed at a fixed output rate. Excess requests rejected or queued:
- Queue capacity = max concurrent requests
- Output rate = allowed throughput
- Use for rate-limiting your own outbound calls to third-party APIs

---

## Redis Implementations

### Token Bucket with Lua (Atomic)

```lua
-- token_bucket.lua
-- KEYS[1] = rate limit key (e.g., "rl:user:123")
-- ARGV[1] = bucket capacity
-- ARGV[2] = refill rate (tokens per second)
-- ARGV[3] = requested tokens (usually 1)
-- ARGV[4] = current timestamp (milliseconds)
-- Returns: [allowed (0/1), remaining_tokens, retry_after_ms]

local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local requested = tonumber(ARGV[3])
local now = tonumber(ARGV[4])

local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
local tokens = tonumber(bucket[1]) or capacity
local last_refill = tonumber(bucket[2]) or now

-- Refill tokens based on elapsed time
local elapsed = (now - last_refill) / 1000  -- convert to seconds
local new_tokens = math.min(capacity, tokens + elapsed * refill_rate)

if new_tokens >= requested then
  -- Allow request
  new_tokens = new_tokens - requested
  redis.call('HMSET', key, 'tokens', new_tokens, 'last_refill', now)
  redis.call('PEXPIRE', key, math.ceil(capacity / refill_rate * 1000))
  return {1, math.floor(new_tokens), 0}
else
  -- Deny request
  local retry_after = math.ceil((requested - new_tokens) / refill_rate * 1000)
  redis.call('HMSET', key, 'tokens', new_tokens, 'last_refill', now)
  redis.call('PEXPIRE', key, math.ceil(capacity / refill_rate * 1000))
  return {0, math.floor(new_tokens), retry_after}
end
```

```typescript
import { createClient } from 'redis';
import { readFileSync } from 'fs';

const redis = createClient({ url: process.env.REDIS_URL });
const tokenBucketScript = readFileSync('./scripts/token_bucket.lua', 'utf8');

interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  retryAfterMs: number;
}

async function checkTokenBucket(
  key: string,
  capacity: number,
  refillRate: number,   // tokens per second
  requested = 1
): Promise<RateLimitResult> {
  const now = Date.now();
  const result = await redis.eval(
    tokenBucketScript,
    { keys: [key], arguments: [String(capacity), String(refillRate), String(requested), String(now)] }
  ) as [number, number, number];

  return {
    allowed: result[0] === 1,
    remaining: result[1],
    retryAfterMs: result[2],
  };
}
```

### Sliding Window Counter with Redis

```typescript
async function checkSlidingWindowCounter(
  key: string,
  limit: number,
  windowMs: number
): Promise<RateLimitResult> {
  const now = Date.now();
  const windowStart = now - windowMs;
  const currentWindow = Math.floor(now / windowMs);
  const prevWindow = currentWindow - 1;

  // Atomic pipeline
  const pipeline = redis.multi();
  pipeline.get(`${key}:${prevWindow}`);
  pipeline.get(`${key}:${currentWindow}`);
  pipeline.incr(`${key}:${currentWindow}`);
  pipeline.pexpire(`${key}:${currentWindow}`, windowMs * 2);

  const results = await pipeline.exec();
  const prevCount = parseInt(results[0] as string ?? '0', 10);
  const currCount = parseInt(results[2] as string ?? '0', 10); // after INCR

  // Interpolate: weight previous window by how far into current window we are
  const elapsedFraction = (now % windowMs) / windowMs;
  const weightedCount = prevCount * (1 - elapsedFraction) + currCount;

  const allowed = weightedCount <= limit;
  const remaining = Math.max(0, limit - Math.ceil(weightedCount));

  return {
    allowed,
    remaining,
    retryAfterMs: allowed ? 0 : windowMs - (now % windowMs),
  };
}
```

### express-rate-limit with Redis Store

```bash
npm install express-rate-limit @express-rate-limit/redis
```

```typescript
import rateLimit from 'express-rate-limit';
import { RedisStore } from '@express-rate-limit/redis';
import { createClient } from 'redis';

const redisClient = createClient({ url: process.env.REDIS_URL });
await redisClient.connect();

export const apiLimiter = rateLimit({
  windowMs: 60 * 1000,    // 1 minute
  max: 100,
  standardHeaders: 'draft-7',  // RateLimit headers (IETF draft 7)
  legacyHeaders: false,
  store: new RedisStore({
    sendCommand: (...args: string[]) => redisClient.sendCommand(args),
  }),
  keyGenerator: (req) => {
    // Rate limit by authenticated user ID, fall back to IP
    return req.user?.id ?? req.ip ?? 'anonymous';
  },
  handler: (req, res) => {
    res.status(429).json({
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests. Please slow down.',
      retryAfter: Math.ceil(res.getHeader('Retry-After') as number),
    });
  },
});
```

---

## Multi-Layer Rate Limiting

Defense in depth — each layer handles different attack vectors:

```
Internet → [Layer 1: CDN/Edge] → [Layer 2: API Gateway] → [Layer 3: App] → [Layer 4: DB]
```

### Layer 1: CDN/Edge (Cloudflare)

Handles volumetric attacks and broad IP-based throttling:
- Rule: 10,000 req/min per IP for broad protection
- Block known bad actors via IP lists
- Challenge suspicious traffic with CAPTCHA
- DDoS protection at the network level

Cloudflare Workers rate limiting (zone-level):
```javascript
// Cloudflare Worker — runs at edge before hitting origin
export default {
  async fetch(request, env) {
    const ip = request.headers.get('CF-Connecting-IP');
    const key = `rl:${ip}`;
    const { success } = await env.RATE_LIMITER.limit({ key });

    if (!success) {
      return new Response('Rate limited', { status: 429 });
    }
    return fetch(request);
  }
};
```

### Layer 2: API Gateway (Kong / AWS API Gateway)

Per-endpoint, per-API-key throttling:
- Kong plugin: `rate-limiting` (100 req/min per consumer per route)
- AWS API Gateway: Usage Plans with API keys
- Nginx: `limit_req_zone` + `limit_req`

```nginx
# Nginx rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
limit_req_zone $http_x_api_key zone=apikey:10m rate=1000r/m;

location /api/ {
    limit_req zone=api burst=20 nodelay;
    limit_req zone=apikey burst=200 nodelay;
    proxy_pass http://backend;
}
```

### Layer 3: Application (express-rate-limit)

User-aware, plan-aware limiting:
- Free: 100 req/min
- Pro: 1,000 req/min
- Enterprise: 10,000 req/min
- Admin: unlimited

### Layer 4: Database

Connection pooling as implicit rate limiting:
- Pool max connections = 20 → at most 20 concurrent DB operations
- Long-running queries → blocked by pool → upstream pressure
- Set query timeouts: `SET statement_timeout = '5s'`

---

## Tiered Limits by Plan

```typescript
type Plan = 'free' | 'pro' | 'enterprise' | 'admin';

const RATE_LIMITS: Record<Plan, { rpm: number; burst: number }> = {
  free:       { rpm: 100,    burst: 20   },
  pro:        { rpm: 1_000,  burst: 200  },
  enterprise: { rpm: 10_000, burst: 2000 },
  admin:      { rpm: Infinity, burst: Infinity },
};

// Middleware that applies plan-based limits
export function planRateLimit(): RequestHandler {
  return async (req, res, next) => {
    if (!req.user) return next(); // Unauthenticated handled elsewhere

    const plan: Plan = req.user.plan ?? 'free';
    const limits = RATE_LIMITS[plan];

    if (limits.rpm === Infinity) return next(); // Admin bypass

    const key = `rl:user:${req.user.id}`;
    const result = await checkTokenBucket(key, limits.burst, limits.rpm / 60);

    // Set standard headers
    res.set('X-RateLimit-Limit', String(limits.rpm));
    res.set('X-RateLimit-Remaining', String(result.remaining));
    res.set('X-RateLimit-Reset', String(Math.ceil((Date.now() + result.retryAfterMs) / 1000)));
    res.set('X-RateLimit-Policy', `${limits.rpm};w=60`);

    if (!result.allowed) {
      res.set('Retry-After', String(Math.ceil(result.retryAfterMs / 1000)));
      return res.status(429).json({
        code: 'RATE_LIMIT_EXCEEDED',
        message: `Rate limit exceeded. Your plan allows ${limits.rpm} requests per minute.`,
        plan,
        upgradeUrl: 'https://example.com/pricing',
      });
    }

    next();
  };
}
```

---

## Rate Limit Headers (Standard)

Follow IETF draft-7 (`RateLimit` header) or legacy `X-RateLimit-*`:

```http
# IETF draft-7 (preferred — single header)
RateLimit: limit=100, remaining=87, reset=42

# Legacy X-RateLimit-* (widely supported)
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1700000042    # Unix timestamp when window resets
X-RateLimit-Policy: 100;w=60    # 100 per 60-second window

# On 429 response
Retry-After: 14                  # Seconds to wait (required on 429)
```

---

## Adaptive Rate Limiting

Dynamically lower limits when the system is under stress:

```typescript
interface SystemLoad {
  cpuPercent: number;
  memoryPercent: number;
  p99LatencyMs: number;
}

function adaptiveLimit(baseLimit: number, load: SystemLoad): number {
  let multiplier = 1.0;

  // Reduce limit under high CPU
  if (load.cpuPercent > 80) multiplier *= 0.5;
  else if (load.cpuPercent > 60) multiplier *= 0.75;

  // Reduce under high memory
  if (load.memoryPercent > 90) multiplier *= 0.5;
  else if (load.memoryPercent > 75) multiplier *= 0.75;

  // Reduce under high latency (DB or upstream slow)
  if (load.p99LatencyMs > 2000) multiplier *= 0.25;
  else if (load.p99LatencyMs > 1000) multiplier *= 0.5;

  return Math.max(1, Math.floor(baseLimit * multiplier));
}

// Refresh system load every 5 seconds from metrics
let currentLoad: SystemLoad = { cpuPercent: 0, memoryPercent: 0, p99LatencyMs: 0 };
setInterval(async () => {
  currentLoad = await getSystemLoad();
}, 5000);
```

---

## DDoS Mitigation

### IP Allowlisting/Blocklisting

```typescript
// Dynamic blocklist stored in Redis set
async function isBlocklisted(ip: string): Promise<boolean> {
  return (await redis.sIsMember('rl:blocklist', ip));
}

async function blockIp(ip: string, ttlSeconds = 3600): Promise<void> {
  await redis.sAdd('rl:blocklist', ip);
  await redis.expire('rl:blocklist', ttlSeconds);
}

// Middleware
router.use(async (req, res, next) => {
  const ip = req.ip!;
  if (await isBlocklisted(ip)) {
    return res.status(403).json({ error: 'Access denied' });
  }
  next();
});
```

### Honeypot Endpoints

```typescript
// Endpoints that legitimate clients never call
// Any request here → auto-block the IP
const HONEYPOT_PATHS = ['/admin.php', '/.env', '/wp-login.php', '/config.php'];

router.use((req, res, next) => {
  if (HONEYPOT_PATHS.includes(req.path)) {
    blockIp(req.ip!);  // Auto-ban
    logger.warn({ ip: req.ip, path: req.path }, 'Honeypot triggered');
    return res.status(404).send();
  }
  next();
});
```

---

## Circuit Breaker + Rate Limiter Interaction

The two patterns are complementary:

- **Rate limiter**: controls *request volume* into the system
- **Circuit breaker**: stops requests when a *downstream dependency* is failing

```typescript
import CircuitBreaker from 'opossum';

const dbCircuitBreaker = new CircuitBreaker(executeQuery, {
  timeout: 3000,          // Fail if query takes > 3s
  errorThresholdPercentage: 50,  // Open circuit if >50% errors
  resetTimeout: 30000,    // Try again after 30s
});

// Combined middleware
router.get('/data', planRateLimit(), async (req, res) => {
  try {
    const result = await dbCircuitBreaker.fire(req.query);
    res.json(result);
  } catch (err) {
    if (dbCircuitBreaker.opened) {
      // Circuit is open — return 503, not 500
      // This also prevents rate limit tokens from being consumed unnecessarily
      res.status(503).json({
        code: 'SERVICE_UNAVAILABLE',
        message: 'Database temporarily unavailable',
        retryAfter: 30,
      });
    } else {
      throw err;
    }
  }
});
```

When the circuit opens, consider not consuming rate limit tokens — the failure is on your side, not the client's.
