# Node.js Backend Patterns - Full Reference

Detailed code examples for the js-ts-dev skill. See SKILL.md for summary.

## Express Setup

```typescript
import express, { Request, Response, NextFunction } from "express";
import helmet from "helmet";
import cors from "cors";
import compression from "compression";

const app = express();
app.use(helmet());
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(",") }));
app.use(compression());
app.use(express.json({ limit: "10mb" }));
```

## Fastify Setup

```typescript
import Fastify from "fastify";

const fastify = Fastify({
  logger: { level: process.env.LOG_LEVEL || "info" },
});

// Type-safe route with schema validation
fastify.post<{ Body: { name: string; email: string }; Reply: { id: string } }>(
  "/users",
  { schema: { body: { type: "object", required: ["name", "email"], properties: { name: { type: "string" }, email: { type: "string", format: "email" } } } } },
  async (request) => ({ id: "123" }),
);
```

## Layered Architecture

```typescript
// Controller - handles HTTP
class UserController {
  constructor(private userService: UserService) {}
  async createUser(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await this.userService.createUser(req.body);
      res.status(201).json(user);
    } catch (error) { next(error); }
  }
}

// Service - business logic
class UserService {
  constructor(private userRepository: UserRepository) {}
  async createUser(userData: CreateUserDTO): Promise<User> {
    const existing = await this.userRepository.findByEmail(userData.email);
    if (existing) throw new ValidationError("Email already exists");
    const hashedPassword = await bcrypt.hash(userData.password, 10);
    const user = await this.userRepository.create({ ...userData, password: hashedPassword });
    const { password, ...safe } = user;
    return safe as User;
  }
}

// Repository - data access
class UserRepository {
  constructor(private db: Pool) {}
  async create(data: CreateUserDTO & { password: string }): Promise<UserEntity> {
    const { rows } = await this.db.query(
      "INSERT INTO users (name, email, password) VALUES ($1, $2, $3) RETURNING *",
      [data.name, data.email, data.password],
    );
    return rows[0];
  }
}
```

## Dependency Injection Container

Why: Centralizes wiring, makes testing easy (swap real repos for mocks).

```typescript
class Container {
  private instances = new Map<string, any>();

  singleton<T>(key: string, factory: () => T): void {
    let instance: T;
    this.instances.set(key, () => instance ??= factory());
  }

  resolve<T>(key: string): T {
    const factory = this.instances.get(key);
    if (!factory) throw new Error(`No factory for ${key}`);
    return factory();
  }
}

const container = new Container();
container.singleton("db", () => new Pool({ host: process.env.DB_HOST, max: 20 }));
container.singleton("userRepo", () => new UserRepository(container.resolve("db")));
container.singleton("userService", () => new UserService(container.resolve("userRepo")));
```

## Error Classes

```typescript
class AppError extends Error {
  constructor(public message: string, public statusCode = 500, public isOperational = true) {
    super(message);
    Object.setPrototypeOf(this, AppError.prototype);
  }
}
class ValidationError extends AppError { constructor(msg: string, public errors?: any[]) { super(msg, 400); } }
class NotFoundError extends AppError { constructor(msg = "Not found") { super(msg, 404); } }
class UnauthorizedError extends AppError { constructor(msg = "Unauthorized") { super(msg, 401); } }

// Global handler
const errorHandler = (err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ status: "error", message: err.message });
  }
  logger.error({ error: err.message, stack: err.stack });
  res.status(500).json({ status: "error", message: process.env.NODE_ENV === "production" ? "Internal server error" : err.message });
};

// Async wrapper - catches promise rejections and forwards to error handler
const asyncHandler = (fn: Function) => (req: Request, res: Response, next: NextFunction) =>
  Promise.resolve(fn(req, res, next)).catch(next);
```

## Auth Middleware

```typescript
const authenticate = async (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.replace("Bearer ", "");
  if (!token) throw new UnauthorizedError("No token");
  req.user = jwt.verify(token, process.env.JWT_SECRET!) as JWTPayload;
  next();
};

const authorize = (...roles: string[]) => (req: Request, res: Response, next: NextFunction) => {
  if (!roles.some(r => req.user?.roles?.includes(r))) return next(new UnauthorizedError("Insufficient permissions"));
  next();
};
```

## Rate Limiting

```typescript
import rateLimit from "express-rate-limit";
import RedisStore from "rate-limit-redis";

export const apiLimiter = rateLimit({
  store: new RedisStore({ client: redis, prefix: "rl:" }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter limit for auth endpoints - prevents brute force
export const authLimiter = rateLimit({
  store: new RedisStore({ client: redis, prefix: "rl:auth:" }),
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,
});
```

## Request Logging

```typescript
import pino from "pino";

const logger = pino({ level: process.env.LOG_LEVEL || "info" });

export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  res.on("finish", () => {
    logger.info({
      method: req.method, url: req.url, status: res.statusCode,
      duration: `${Date.now() - start}ms`, ip: req.ip,
    });
  });
  next();
};
```

## Validation with Zod

```typescript
import { z } from "zod";

const createUserSchema = z.object({
  body: z.object({ name: z.string().min(1), email: z.string().email(), password: z.string().min(8) }),
});

const validate = (schema: AnyZodObject) => async (req: Request, res: Response, next: NextFunction) => {
  try { await schema.parseAsync({ body: req.body, query: req.query, params: req.params }); next(); }
  catch (error) { next(new ValidationError("Validation failed", (error as ZodError).errors)); }
};

router.post("/users", validate(createUserSchema), userController.createUser);
```

## Transaction Pattern

```typescript
async createOrder(userId: string, items: any[]) {
  const client = await this.db.connect();
  try {
    await client.query("BEGIN");
    // ... insert order, items, update inventory
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
```

## Redis Caching

```typescript
class CacheService {
  async get<T>(key: string): Promise<T | null> {
    const data = await redis.get(key);
    return data ? JSON.parse(data) : null;
  }
  async set(key: string, value: any, ttl?: number): Promise<void> {
    ttl ? await redis.setex(key, ttl, JSON.stringify(value)) : await redis.set(key, JSON.stringify(value));
  }
  async invalidatePattern(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern);
    if (keys.length) await redis.del(...keys);
  }
}

// Cache decorator - auto-cache method results
function Cacheable(ttl: number = 300) {
  return function (target: any, key: string, descriptor: PropertyDescriptor) {
    const original = descriptor.value;
    descriptor.value = async function (...args: any[]) {
      const cache = new CacheService();
      const cacheKey = `${key}:${JSON.stringify(args)}`;
      const cached = await cache.get(cacheKey);
      if (cached) return cached;
      const result = await original.apply(this, args);
      await cache.set(cacheKey, result, ttl);
      return result;
    };
    return descriptor;
  };
}
```

## JWT Auth Service

```typescript
class AuthService {
  async login(email: string, password: string) {
    const user = await this.userRepository.findByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.password)))
      throw new UnauthorizedError("Invalid credentials");
    return {
      token: jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET!, { expiresIn: "15m" }),
      refreshToken: jwt.sign({ userId: user.id }, process.env.REFRESH_TOKEN_SECRET!, { expiresIn: "7d" }),
    };
  }

  async refresh(refreshToken: string) {
    const payload = jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET!) as { userId: string };
    const user = await this.userRepository.findById(payload.userId);
    if (!user) throw new UnauthorizedError("User not found");
    return { token: jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET!, { expiresIn: "15m" }) };
  }
}
```

## API Response Format

```typescript
class ApiResponse {
  static success<T>(res: Response, data: T, statusCode = 200) {
    return res.status(statusCode).json({ status: "success", data });
  }
  static error(res: Response, message: string, statusCode = 500, errors?: any) {
    return res.status(statusCode).json({ status: "error", message, ...(errors && { errors }) });
  }
  static paginated<T>(res: Response, data: T[], page: number, limit: number, total: number) {
    return res.json({ status: "success", data, pagination: { page, limit, total, pages: Math.ceil(total / limit) } });
  }
}
```

## Graceful Shutdown

```typescript
const server = app.listen(PORT);

async function shutdown(signal: string) {
  logger.info(`${signal} received, shutting down gracefully`);
  server.close(() => logger.info("HTTP server closed"));
  await pool.end();       // close DB connections
  await redis.quit();     // close Redis
  process.exit(0);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```
