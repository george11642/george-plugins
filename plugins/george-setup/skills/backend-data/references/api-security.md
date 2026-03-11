# API Security Patterns

Production-ready security patterns for Node.js backends. Covers JWT, OAuth 2.0, API keys, rate limiting, input validation, SQL injection prevention, CORS, security headers, password hashing, and secrets management.

---

## JWT Authentication

### Sign and Verify

```typescript
// src/utils/jwt.ts
import jwt from 'jsonwebtoken';
import { UnauthorizedError } from './errors';

export interface JWTPayload {
  sub:   string;   // userId (subject)
  email: string;
  roles: string[];
  iat?:  number;
  exp?:  number;
}

const ACCESS_TOKEN_TTL  = '15m';
const REFRESH_TOKEN_TTL = '7d';

export function signAccessToken(payload: Omit<JWTPayload, 'iat' | 'exp'>): string {
  return jwt.sign(payload, process.env.JWT_SECRET!, {
    expiresIn: ACCESS_TOKEN_TTL,
    issuer:    process.env.JWT_ISSUER ?? 'api',
    audience:  process.env.JWT_AUDIENCE ?? 'app',
  });
}

export function signRefreshToken(userId: string): string {
  return jwt.sign({ sub: userId }, process.env.JWT_REFRESH_SECRET!, {
    expiresIn: REFRESH_TOKEN_TTL,
  });
}

export function verifyAccessToken(token: string): JWTPayload {
  try {
    return jwt.verify(token, process.env.JWT_SECRET!, {
      issuer:   process.env.JWT_ISSUER ?? 'api',
      audience: process.env.JWT_AUDIENCE ?? 'app',
    }) as JWTPayload;
  } catch (err) {
    throw new UnauthorizedError('Token invalid or expired');
  }
}

export function verifyRefreshToken(token: string): { sub: string } {
  try {
    return jwt.verify(token, process.env.JWT_REFRESH_SECRET!) as { sub: string };
  } catch {
    throw new UnauthorizedError('Refresh token invalid or expired');
  }
}
```

### Refresh Token Rotation

```typescript
// src/services/auth.service.ts
import bcrypt from 'bcrypt';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from '../utils/jwt';
import { UserRepository } from '../repositories/user.repository';
import { TokenRepository } from '../repositories/token.repository';
import { UnauthorizedError } from '../utils/errors';

export class AuthService {
  constructor(
    private users:  UserRepository,
    private tokens: TokenRepository,
  ) {}

  async login(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user) throw new UnauthorizedError('Invalid credentials');

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) throw new UnauthorizedError('Invalid credentials');

    const accessToken  = signAccessToken({ sub: user.id, email: user.email, roles: user.roles });
    const refreshToken = signRefreshToken(user.id);

    // Store refresh token hash (never store plaintext)
    const hash = await bcrypt.hash(refreshToken, 10);
    await this.tokens.store(user.id, hash, new Date(Date.now() + 7 * 86_400_000));

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email, name: user.name },
    };
  }

  async refresh(refreshToken: string) {
    const { sub: userId } = verifyRefreshToken(refreshToken);

    const stored = await this.tokens.findByUserId(userId);
    if (!stored) throw new UnauthorizedError('Refresh token revoked');

    const valid = await bcrypt.compare(refreshToken, stored.hash);
    if (!valid) throw new UnauthorizedError('Refresh token mismatch');

    // Rotation: revoke old token, issue new pair
    await this.tokens.revoke(stored.id);

    const user         = await this.users.findById(userId);
    if (!user) throw new UnauthorizedError('User not found');

    const newAccess  = signAccessToken({ sub: user.id, email: user.email, roles: user.roles });
    const newRefresh = signRefreshToken(user.id);
    const hash       = await bcrypt.hash(newRefresh, 10);
    await this.tokens.store(user.id, hash, new Date(Date.now() + 7 * 86_400_000));

    return { accessToken: newAccess, refreshToken: newRefresh };
  }

  async logout(refreshToken: string) {
    try {
      const { sub: userId } = verifyRefreshToken(refreshToken);
      await this.tokens.revokeAll(userId);
    } catch {
      // Ignore invalid tokens on logout — just clear cookies on client
    }
  }
}
```

### Auth Middleware (Express)

```typescript
// src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken, JWTPayload } from '../utils/jwt';
import { UnauthorizedError, ForbiddenError } from '../utils/errors';

declare global {
  namespace Express {
    interface Request { user?: JWTPayload }
  }
}

export const authenticate = (req: Request, _res: Response, next: NextFunction) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return next(new UnauthorizedError('Missing Authorization header'));
  }
  try {
    req.user = verifyAccessToken(header.slice(7));
    next();
  } catch (err) {
    next(err);
  }
};

export const requireRoles = (...roles: string[]) =>
  (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user)  return next(new UnauthorizedError('Not authenticated'));
    if (!roles.some(r => req.user!.roles.includes(r))) {
      return next(new ForbiddenError('Insufficient permissions'));
    }
    next();
  };

// Convenience helpers
export const requireAdmin  = requireRoles('admin');
export const requireStaff  = requireRoles('admin', 'staff');
```

---

## OAuth 2.0

### Authorization Code Flow (with PKCE)

```typescript
// src/services/oauth.service.ts
import crypto from 'crypto';

export class OAuthService {
  // Step 1: Generate PKCE challenge for the client
  generatePKCE() {
    const verifier  = crypto.randomBytes(32).toString('base64url');
    const challenge = crypto.createHash('sha256').update(verifier).digest('base64url');
    return { verifier, challenge };
  }

  // Step 2: Build authorization URL
  buildAuthURL(params: {
    provider:     'github' | 'google';
    challenge:    string;
    state:        string;
    redirectUri:  string;
    scopes:       string[];
  }): string {
    const configs = {
      github: { authUrl: 'https://github.com/login/oauth/authorize', clientId: process.env.GITHUB_CLIENT_ID! },
      google: { authUrl: 'https://accounts.google.com/o/oauth2/v2/auth', clientId: process.env.GOOGLE_CLIENT_ID! },
    };

    const { authUrl, clientId } = configs[params.provider];
    const url = new URL(authUrl);
    url.searchParams.set('client_id',             clientId);
    url.searchParams.set('redirect_uri',          params.redirectUri);
    url.searchParams.set('response_type',         'code');
    url.searchParams.set('scope',                 params.scopes.join(' '));
    url.searchParams.set('state',                 params.state);
    url.searchParams.set('code_challenge',        params.challenge);
    url.searchParams.set('code_challenge_method', 'S256');
    return url.toString();
  }

  // Step 3: Exchange code for tokens
  async exchangeCode(provider: 'github' | 'google', code: string, verifier: string, redirectUri: string) {
    const tokenUrls = {
      github: 'https://github.com/login/oauth/access_token',
      google: 'https://oauth2.googleapis.com/token',
    };
    const secrets = {
      github: { clientId: process.env.GITHUB_CLIENT_ID!, clientSecret: process.env.GITHUB_CLIENT_SECRET! },
      google: { clientId: process.env.GOOGLE_CLIENT_ID!, clientSecret: process.env.GOOGLE_CLIENT_SECRET! },
    };

    const { clientId, clientSecret } = secrets[provider];

    const res = await fetch(tokenUrls[provider], {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
      body: new URLSearchParams({
        grant_type:    'authorization_code',
        code,
        redirect_uri:  redirectUri,
        client_id:     clientId,
        client_secret: clientSecret,
        code_verifier: verifier,
      }),
    });

    if (!res.ok) throw new Error(`Token exchange failed: ${res.statusText}`);
    return res.json() as Promise<{ access_token: string; token_type: string; scope: string }>;
  }
}
```

### Client Credentials Flow (Machine-to-Machine)

```typescript
// src/middleware/m2m-auth.middleware.ts
// Used when one service calls another — no user involved

export async function clientCredentials(clientId: string, clientSecret: string, tokenUrl: string) {
  const creds = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const res   = await fetch(tokenUrl, {
    method:  'POST',
    headers: { Authorization: `Basic ${creds}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    new URLSearchParams({ grant_type: 'client_credentials', scope: 'api:read api:write' }),
  });
  if (!res.ok) throw new Error('Client credentials exchange failed');
  return res.json() as Promise<{ access_token: string; expires_in: number }>;
}
```

---

## API Key Authentication

```typescript
// src/middleware/api-key.middleware.ts
import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { UnauthorizedError } from '../utils/errors';
import { ApiKeyRepository } from '../repositories/api-key.repository';

export const apiKeyAuth = (repo: ApiKeyRepository) =>
  async (req: Request, _res: Response, next: NextFunction) => {
    const raw = req.headers['x-api-key'] as string;
    if (!raw) return next(new UnauthorizedError('Missing X-API-Key header'));

    // Hash the incoming key — never store plaintext API keys
    const hash = crypto.createHmac('sha256', process.env.API_KEY_SECRET!)
      .update(raw)
      .digest('hex');

    const keyRecord = await repo.findByHash(hash);
    if (!keyRecord || keyRecord.revokedAt) {
      return next(new UnauthorizedError('Invalid API key'));
    }

    await repo.updateLastUsed(keyRecord.id);
    req.user = { sub: keyRecord.ownerId, email: '', roles: keyRecord.scopes };
    next();
  };

// Generate a new API key
export function generateApiKey(): { raw: string; hash: string; prefix: string } {
  const bytes  = crypto.randomBytes(32);
  const raw    = `ak_${bytes.toString('base64url')}`;
  const prefix = raw.slice(0, 8);
  const hash   = crypto.createHmac('sha256', process.env.API_KEY_SECRET!)
    .update(raw)
    .digest('hex');
  return { raw, hash, prefix };
}
```

---

## Input Validation with Zod

Always validate every external input. Schema defines both shape and sanitization:

```typescript
// src/models/schemas.ts
import { z } from 'zod';

// Reusable primitives
const uuid      = z.string().uuid();
const email     = z.string().email().toLowerCase().trim();
const password  = z.string().min(8).max(128).regex(
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
  'Password must contain lowercase, uppercase, and a digit',
);
const safeStr   = (max = 255) => z.string().min(1).max(max).trim();
const positiveInt = z.coerce.number().int().positive();

// User schemas
export const CreateUserSchema = z.object({
  body: z.object({
    name:     safeStr(100),
    email,
    password,
    role:     z.enum(['user', 'admin']).default('user'),
  }),
});

export const UpdateUserSchema = z.object({
  params: z.object({ id: uuid }),
  body:   z.object({
    name:  safeStr(100).optional(),
    email: email.optional(),
  }).refine(obj => Object.keys(obj).length > 0, 'At least one field required'),
});

export const PaginationSchema = z.object({
  query: z.object({
    page:  z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    sort:  z.enum(['created_at', 'updated_at', 'name']).default('created_at'),
    order: z.enum(['asc', 'desc']).default('desc'),
  }),
});

// Validate middleware (from nodejs-patterns.md — shown here for completeness)
export const validate = (schema: z.AnyZodObject) =>
  async (req: Request, _res: Response, next: NextFunction) => {
    const result = await schema.safeParseAsync({
      body: req.body, query: req.query, params: req.params,
    });
    if (!result.success) {
      return next(new ValidationError('Validation failed', result.error.errors.map(e => ({
        field:   e.path.join('.'),
        message: e.message,
      }))));
    }
    Object.assign(req, result.data);
    next();
  };
```

---

## SQL Injection Prevention

**Rule: always use parameterized queries. Never interpolate user input into SQL strings.**

```typescript
// WRONG — never do this
const { rows } = await db.query(`SELECT * FROM users WHERE email = '${email}'`);

// CORRECT — parameterized
const { rows } = await db.query('SELECT * FROM users WHERE email = $1', [email]);

// CORRECT — dynamic column selection (whitelist approach)
const ALLOWED_SORT_COLUMNS = ['name', 'created_at', 'email'] as const;
type SortColumn = typeof ALLOWED_SORT_COLUMNS[number];

function isSortColumn(s: string): s is SortColumn {
  return ALLOWED_SORT_COLUMNS.includes(s as SortColumn);
}

async function listUsers(sortBy: string, order: string) {
  // Validate against whitelist before embedding in query
  const col = isSortColumn(sortBy) ? sortBy : 'created_at';
  const dir = order === 'asc' ? 'ASC' : 'DESC'; // only two possible values

  const { rows } = await db.query(
    `SELECT id, name, email FROM users ORDER BY ${col} ${dir} LIMIT $1 OFFSET $2`,
    [limit, offset],
  );
  return rows;
}

// CORRECT — Bulk insert with unnest (PostgreSQL)
async function bulkInsert(users: Array<{ name: string; email: string }>) {
  const names  = users.map(u => u.name);
  const emails = users.map(u => u.email);
  const { rows } = await db.query(
    'INSERT INTO users (name, email) SELECT * FROM unnest($1::text[], $2::text[]) RETURNING id',
    [names, emails],
  );
  return rows;
}
```

---

## CORS Configuration

```typescript
// src/config/cors.ts
import cors, { CorsOptions } from 'cors';

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean);

export const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin) return callback(null, true);
    if (ALLOWED_ORIGINS.includes(origin)) return callback(null, true);
    callback(new Error(`CORS blocked for origin: ${origin}`));
  },
  credentials:     true,    // allow cookies/authorization headers
  methods:         ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders:  ['Content-Type', 'Authorization', 'X-Request-ID', 'X-API-Key'],
  exposedHeaders:  ['X-Request-ID', 'X-RateLimit-Limit', 'X-RateLimit-Remaining'],
  maxAge:          86_400,  // preflight cache 24h
};

// Usage in app.ts
// app.use(cors(corsOptions));
```

---

## Security Headers with Helmet

```typescript
// src/config/helmet.ts
import helmet, { HelmetOptions } from 'helmet';

export const helmetConfig: HelmetOptions = {
  // Content Security Policy — adjust for your frontend
  contentSecurityPolicy: {
    directives: {
      defaultSrc:     ["'self'"],
      scriptSrc:      ["'self'"],
      styleSrc:       ["'self'", "'unsafe-inline'"],
      imgSrc:         ["'self'", 'data:', 'https:'],
      connectSrc:     ["'self'"],
      fontSrc:        ["'self'"],
      objectSrc:      ["'none'"],
      mediaSrc:       ["'self'"],
      frameSrc:       ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  hsts: {
    maxAge:            31_536_000, // 1 year
    includeSubDomains: true,
    preload:           true,
  },
  noSniff:           true,   // X-Content-Type-Options: nosniff
  frameguard:        { action: 'deny' },   // X-Frame-Options: DENY
  xssFilter:         true,
  referrerPolicy:    { policy: 'strict-origin-when-cross-origin' },
  permittedCrossDomainPolicies: { permittedPolicies: 'none' },
};

// Usage: app.use(helmet(helmetConfig));
```

---

## Password Hashing with bcrypt

```typescript
// src/utils/password.ts
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12; // ~300ms on modern hardware — balance security vs UX

export async function hashPassword(plaintext: string): Promise<string> {
  return bcrypt.hash(plaintext, SALT_ROUNDS);
}

export async function verifyPassword(plaintext: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plaintext, hash);
}

// Check if hash needs re-hashing (e.g., after increasing SALT_ROUNDS)
export async function needsRehash(hash: string): Promise<boolean> {
  const currentRounds = bcrypt.getRounds(hash);
  return currentRounds < SALT_ROUNDS;
}

// Usage in login flow
async function login(email: string, password: string) {
  const user = await userRepo.findByEmail(email);
  if (!user) {
    // Timing-safe: always hash even if user not found
    await hashPassword(password);
    throw new UnauthorizedError('Invalid credentials');
  }

  const valid = await verifyPassword(password, user.password);
  if (!valid) throw new UnauthorizedError('Invalid credentials');

  // Opportunistically upgrade hash if needed
  if (await needsRehash(user.password)) {
    const newHash = await hashPassword(password);
    await userRepo.updatePassword(user.id, newHash);
  }

  return user;
}
```

---

## Rate Limiting Strategies

### Sliding Window (Redis)

```typescript
// src/utils/rate-limiter.ts
import { redis } from '../config/redis';

interface RateLimitResult {
  allowed:    boolean;
  remaining:  number;
  resetAfter: number; // seconds
}

// Sliding window log using Redis sorted sets
export async function slidingWindowRateLimit(
  key:         string,
  maxRequests: number,
  windowMs:    number,
): Promise<RateLimitResult> {
  const now   = Date.now();
  const start = now - windowMs;
  const multi = redis.multi();

  // Remove entries outside the window
  multi.zremrangebyscore(key, '-inf', start);
  // Add current request
  multi.zadd(key, now, `${now}-${Math.random()}`);
  // Count requests in window
  multi.zcard(key);
  // Set expiry
  multi.pexpire(key, windowMs);

  const results = await multi.exec();
  const count   = results?.[2]?.[1] as number ?? 0;

  return {
    allowed:    count <= maxRequests,
    remaining:  Math.max(0, maxRequests - count),
    resetAfter: Math.ceil(windowMs / 1000),
  };
}

// Token bucket (fixed rate)
export async function tokenBucketRateLimit(
  key:      string,
  capacity: number,
  refillRatePerSecond: number,
): Promise<RateLimitResult> {
  const script = `
    local key      = KEYS[1]
    local capacity = tonumber(ARGV[1])
    local refill   = tonumber(ARGV[2])
    local now      = tonumber(ARGV[3])

    local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
    local tokens     = tonumber(bucket[1]) or capacity
    local lastRefill = tonumber(bucket[2]) or now

    local elapsed = (now - lastRefill) / 1000
    tokens = math.min(capacity, tokens + elapsed * refill)

    if tokens >= 1 then
      tokens = tokens - 1
      redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
      redis.call('EXPIRE', key, 3600)
      return {1, math.floor(tokens), 0}
    else
      local waitSec = math.ceil((1 - tokens) / refill)
      return {0, 0, waitSec}
    end
  `;

  const result = await redis.eval(script, 1, key, capacity, refillRatePerSecond, Date.now()) as number[];
  return {
    allowed:    result[0] === 1,
    remaining:  result[1],
    resetAfter: result[2],
  };
}
```

---

## Secrets Management

```typescript
// src/config/env.ts
import { z } from 'zod';

// Validate all required env vars at startup — fail fast
const EnvSchema = z.object({
  NODE_ENV:             z.enum(['development', 'test', 'production']),
  PORT:                 z.coerce.number().default(3000),

  // Database
  DB_HOST:              z.string(),
  DB_PORT:              z.coerce.number().default(5432),
  DB_NAME:              z.string(),
  DB_USER:              z.string(),
  DB_PASSWORD:          z.string().min(1),
  DB_SSL:               z.enum(['true', 'false']).default('false'),

  // Auth
  JWT_SECRET:           z.string().min(32),
  JWT_REFRESH_SECRET:   z.string().min(32),
  JWT_ISSUER:           z.string().default('api'),
  JWT_AUDIENCE:         z.string().default('app'),

  // Redis
  REDIS_HOST:           z.string().default('localhost'),
  REDIS_PORT:           z.coerce.number().default(6379),
  REDIS_PASSWORD:       z.string().optional(),

  // Optional integrations
  STRIPE_SECRET_KEY:    z.string().startsWith('sk_').optional(),
  OPENAI_API_KEY:       z.string().startsWith('sk-').optional(),
});

export type Env = z.infer<typeof EnvSchema>;

const result = EnvSchema.safeParse(process.env);
if (!result.success) {
  console.error('Invalid environment configuration:');
  result.error.errors.forEach(e => console.error(`  ${e.path.join('.')}: ${e.message}`));
  process.exit(1);
}

export const env = result.data;
```

**Rules for secrets:**

```
# NEVER do these:
const apiKey = 'sk-abc123';                    // hardcoded secret
console.log('JWT_SECRET:', process.env.JWT_SECRET);  // log secrets
git add .env                                   // commit .env files
return res.json({ token, secret: apiKey });    // expose in responses

# ALWAYS do these:
const apiKey = process.env.OPENAI_API_KEY;     // read from env
# Use a secrets manager in production (AWS Secrets Manager, Doppler, Vault)
# Rotate secrets regularly and after any suspected leak
# Use different secrets per environment (dev/staging/prod)
# Set minimum length: JWT secrets >= 32 chars, API keys >= 32 random bytes
```

---

## Complete Security Checklist

```
Authentication:
  [ ] JWT signed with strong secret (>= 32 chars entropy)
  [ ] Access tokens short-lived (15m)
  [ ] Refresh tokens rotated on use, stored as bcrypt hash
  [ ] Refresh tokens revoked on logout and password change
  [ ] Auth errors return generic messages (no "user not found" vs "wrong password")

Authorization:
  [ ] Default deny — all routes require auth unless explicitly public
  [ ] Role/scope checked on every protected endpoint
  [ ] Users can only access their own resources (tenant isolation)

Input Validation:
  [ ] Every request body validated with Zod/Joi schema
  [ ] Path params and query strings validated and coerced
  [ ] File uploads: type checked, size limited, name sanitized
  [ ] No raw SQL string interpolation anywhere

Transport:
  [ ] HTTPS enforced (HSTS header)
  [ ] Security headers via helmet
  [ ] CORS allowlist (no wildcard in production)

Rate Limiting:
  [ ] Auth endpoints rate-limited (5 req/15min, skip success)
  [ ] General API rate-limited per IP + per user
  [ ] Expensive ops (file upload, AI calls) have tighter limits
  [ ] 429 responses include Retry-After header

Passwords:
  [ ] bcrypt with >=12 rounds
  [ ] Timing-safe comparison (bcrypt.compare handles this)
  [ ] Password reset uses short-lived signed tokens, not emailed passwords

Secrets:
  [ ] No secrets in code or git history
  [ ] .env in .gitignore
  [ ] Production secrets in secrets manager, not CI env vars
  [ ] Different secrets per environment

Logging:
  [ ] Never log passwords, tokens, or PII
  [ ] Structured logs with request ID for correlation
  [ ] Error logs include stack trace (server-side only)
```
