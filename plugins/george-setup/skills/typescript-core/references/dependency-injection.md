# Dependency Injection in TypeScript

## Why DI?

Dependency Injection makes code testable by allowing real dependencies to be replaced with mocks at test time. It also decouples construction from use, making modules composable and independently replaceable.

---

## Manual DI Container (Map-Based)

A lightweight container without decorators or reflect-metadata. Suitable for Node.js ESM projects or anywhere decorators aren't available.

```typescript
// container.ts
type Constructor<T> = new (...args: any[]) => T
type Factory<T> = () => T
type Token<T> = symbol & { __type: T }

function token<T>(description: string): Token<T> {
  return Symbol(description) as Token<T>
}

class Container {
  private singletons = new Map<symbol, unknown>()
  private factories = new Map<symbol, Factory<unknown>>()

  registerSingleton<T>(token: Token<T>, factory: Factory<T>): void {
    this.factories.set(token, factory)
  }

  registerFactory<T>(token: Token<T>, factory: Factory<T>): void {
    this.factories.set(token, factory)
    // Mark as transient by not caching result
  }

  resolve<T>(token: Token<T>): T {
    // Return cached singleton
    if (this.singletons.has(token)) {
      return this.singletons.get(token) as T
    }

    const factory = this.factories.get(token)
    if (!factory) {
      throw new Error(`No registration for token: ${token.description}`)
    }

    const instance = factory() as T
    this.singletons.set(token, instance) // cache as singleton
    return instance
  }

  // Create a child container for request-scoped deps
  createScope(): Container {
    const scope = new Container()
    scope.factories = new Map(this.factories) // inherit registrations
    return scope
  }
}

export const container = new Container()
export { token }
```

### Interface-Based Injection with Symbols

```typescript
// tokens.ts — define injection tokens
import { token } from './container'
import type { IDatabase } from './database'
import type { IUserRepository } from './repositories/user.repository'
import type { IUserService } from './services/user.service'

export const Tokens = {
  Database: token<IDatabase>('Database'),
  UserRepository: token<IUserRepository>('UserRepository'),
  UserService: token<IUserService>('UserService'),
} as const
```

### Complete Service Layer Example

```typescript
// interfaces.ts
export interface IDatabase {
  query<T>(sql: string, params?: unknown[]): Promise<T[]>
  close(): Promise<void>
}

export interface IUserRepository {
  findById(id: string): Promise<User | null>
  findByEmail(email: string): Promise<User | null>
  create(data: CreateUserDTO): Promise<User>
}

export interface IUserService {
  getUser(id: string): Promise<User>
  createUser(data: CreateUserDTO): Promise<User>
}

// database.ts
export class PostgresDatabase implements IDatabase {
  constructor(private connectionString: string) {}

  async query<T>(sql: string, params?: unknown[]): Promise<T[]> {
    // pg pool query
    return []
  }

  async close(): Promise<void> {}
}

// user.repository.ts
export class UserRepository implements IUserRepository {
  constructor(private db: IDatabase) {}

  async findById(id: string): Promise<User | null> {
    const rows = await this.db.query<User>(
      'SELECT * FROM users WHERE id = $1',
      [id]
    )
    return rows[0] ?? null
  }

  async findByEmail(email: string): Promise<User | null> {
    const rows = await this.db.query<User>(
      'SELECT * FROM users WHERE email = $1',
      [email]
    )
    return rows[0] ?? null
  }

  async create(data: CreateUserDTO): Promise<User> {
    const rows = await this.db.query<User>(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [data.name, data.email]
    )
    return rows[0]!
  }
}

// user.service.ts
export class UserService implements IUserService {
  constructor(private userRepository: IUserRepository) {}

  async getUser(id: string): Promise<User> {
    const user = await this.userRepository.findById(id)
    if (!user) throw new Error(`User ${id} not found`)
    return user
  }

  async createUser(data: CreateUserDTO): Promise<User> {
    const existing = await this.userRepository.findByEmail(data.email)
    if (existing) throw new Error(`Email ${data.email} already registered`)
    return this.userRepository.create(data)
  }
}
```

### Composition Root (App Entry Point)

```typescript
// bootstrap.ts — the ONLY place that knows about concrete classes
import { container } from './container'
import { Tokens } from './tokens'
import { PostgresDatabase } from './database'
import { UserRepository } from './repositories/user.repository'
import { UserService } from './services/user.service'

export function bootstrap(): void {
  const db = new PostgresDatabase(process.env.DATABASE_URL!)

  container.registerSingleton(Tokens.Database, () => db)

  container.registerSingleton(
    Tokens.UserRepository,
    () => new UserRepository(container.resolve(Tokens.Database))
  )

  container.registerSingleton(
    Tokens.UserService,
    () => new UserService(container.resolve(Tokens.UserRepository))
  )
}

// index.ts
import { bootstrap } from './bootstrap'
import { container } from './container'
import { Tokens } from './tokens'

bootstrap()

const userService = container.resolve(Tokens.UserService)
```

### Testing with Manual DI

```typescript
// user.service.test.ts
import { UserService } from './user.service'
import type { IUserRepository } from './interfaces'

function makeMockRepo(overrides?: Partial<IUserRepository>): IUserRepository {
  return {
    findById: vi.fn().mockResolvedValue(null),
    findByEmail: vi.fn().mockResolvedValue(null),
    create: vi.fn().mockResolvedValue({ id: '1', name: 'Test', email: 'test@test.com' }),
    ...overrides,
  }
}

describe('UserService', () => {
  it('throws when user not found', async () => {
    const repo = makeMockRepo({ findById: vi.fn().mockResolvedValue(null) })
    const service = new UserService(repo)
    await expect(service.getUser('missing')).rejects.toThrow('not found')
  })

  it('throws on duplicate email', async () => {
    const existing = { id: '1', name: 'Existing', email: 'x@x.com' }
    const repo = makeMockRepo({ findByEmail: vi.fn().mockResolvedValue(existing) })
    const service = new UserService(repo)
    await expect(service.createUser({ name: 'New', email: 'x@x.com' })).rejects.toThrow('already registered')
  })
})
```

---

## tsyringe (Decorator-Based DI)

Microsoft's lightweight DI container. Requires `reflect-metadata` and decorator support.

```json
// tsconfig.json — required settings
{
  "compilerOptions": {
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  }
}
```

```typescript
// main.ts — import reflect-metadata ONCE at app entry
import 'reflect-metadata'
import { container } from 'tsyringe'
```

```typescript
// database.ts
import { injectable } from 'tsyringe'

@injectable()
export class Database {
  async query<T>(sql: string, params?: unknown[]): Promise<T[]> {
    return []
  }
}

// user.repository.ts
import { injectable, inject } from 'tsyringe'

@injectable()
export class UserRepository {
  constructor(private db: Database) {} // auto-resolved by type

  async findById(id: string) { /* ... */ }
}

// user.service.ts
import { injectable } from 'tsyringe'

@injectable()
export class UserService {
  constructor(private repo: UserRepository) {}
}

// bootstrap.ts
import { container } from 'tsyringe'
import { Database } from './database'
import { UserRepository } from './user.repository'
import { UserService } from './user.service'

// Register interface tokens explicitly
container.register('IDatabase', { useClass: Database })

// Resolve full object graph
const userService = container.resolve(UserService)
```

Testing with tsyringe — register mocks before each test:
```typescript
import { container } from 'tsyringe'

beforeEach(() => {
  container.clearInstances()
  container.register(Database, { useValue: mockDatabase })
})
```

---

## Factory Functions (Functional DI)

For simpler projects or functional-style codebases, factory functions compose cleanly without a container:

```typescript
// factories.ts
export function createDatabase(url: string): IDatabase {
  return new PostgresDatabase(url)
}

export function createUserRepository(db: IDatabase): IUserRepository {
  return new UserRepository(db)
}

export function createUserService(repo: IUserRepository): IUserService {
  return new UserService(repo)
}

// Compose in main
const db = createDatabase(process.env.DATABASE_URL!)
const userRepo = createUserRepository(db)
const userService = createUserService(userRepo)
```

---

## Service Locator vs DI

| | Service Locator | Dependency Injection |
|--|----------------|---------------------|
| How | Class pulls deps from registry | Deps pushed in via constructor |
| Testability | Hard (global registry) | Easy (just pass mocks) |
| Visibility | Hidden dependencies | Explicit in constructor |
| Use when | Legacy code, plugin systems | Greenfield, all new code |

**Prefer constructor injection.** Service locator is an anti-pattern in application code but acceptable in framework plugin systems.

---

## `satisfies` for DI Registration Type Safety

```typescript
// Ensure registration object matches interface without losing literal types
const userServiceConfig = {
  scope: 'singleton',
  tags: ['user', 'core'],
} satisfies ServiceConfig

// tags is still string[], not widened to unknown
console.log(userServiceConfig.tags[0]) // 'user' — type preserved
```
