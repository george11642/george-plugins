# API Design Patterns

## OpenAPI / Swagger

### swagger-jsdoc with Express

```bash
pnpm add swagger-jsdoc swagger-ui-express
pnpm add -D @types/swagger-jsdoc @types/swagger-ui-express
```

```typescript
// swagger.ts
import swaggerJsdoc from 'swagger-jsdoc'
import swaggerUi from 'swagger-ui-express'
import type { Express } from 'express'

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'My API',
      version: '1.0.0',
      description: 'API documentation',
    },
    servers: [
      { url: '/api/v1', description: 'Development' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
  },
  apis: ['./src/routes/**/*.ts'],
}

export const swaggerSpec = swaggerJsdoc(options)

export function setupSwagger(app: Express): void {
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec))
  // Serve raw spec
  app.get('/docs.json', (_req, res) => res.json(swaggerSpec))
}
```

### Route Annotations

```typescript
// routes/users.ts

/**
 * @swagger
 * /users:
 *   get:
 *     summary: List all users
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *     responses:
 *       200:
 *         description: Paginated list of users
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UserList'
 *       401:
 *         $ref: '#/components/responses/Unauthorized'
 *
 * /users/{id}:
 *   get:
 *     summary: Get user by ID
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: User object
 *       404:
 *         $ref: '#/components/responses/NotFound'
 */
router.get('/', listUsers)
router.get('/:id', getUser)
```

### Auto-Generating TypeScript Types from OpenAPI Spec

```bash
pnpm add -D openapi-typescript
```

```bash
# Generate types from a local spec
npx openapi-typescript ./openapi.yaml -o src/types/api.ts

# Or from a remote URL
npx openapi-typescript https://api.example.com/docs.json -o src/types/api.ts
```

```typescript
// Generated usage with openapi-fetch
import createClient from 'openapi-fetch'
import type { paths } from './types/api'

const client = createClient<paths>({ baseUrl: '/api/v1' })

// Fully typed request and response
const { data, error } = await client.GET('/users/{id}', {
  params: { path: { id: '123' } },
})
// data is typed as User from the spec
```

### API Contract Testing

```typescript
// Use the spec to validate responses match schema
import Ajv from 'ajv'
import { swaggerSpec } from './swagger'

const ajv = new Ajv()
const schema = swaggerSpec.components.schemas.User

test('GET /users/:id response matches schema', async () => {
  const response = await request(app).get('/api/v1/users/1').expect(200)
  const validate = ajv.compile(schema)
  expect(validate(response.body)).toBe(true)
})
```

---

## API Versioning Strategies

### URL Versioning (Recommended Default)

```typescript
// Express — separate routers per version
import { v1Router } from './routes/v1'
import { v2Router } from './routes/v2'

app.use('/api/v1', v1Router)
app.use('/api/v2', v2Router)
```

Pros: Visible in URLs, cacheable, easy to bookmark. Cons: URL pollution, clients must update URLs.

### Header Versioning

```typescript
// Middleware to route by API-Version header
app.use('/api', (req, res, next) => {
  const version = req.headers['api-version'] ?? '1'
  req.apiVersion = Number(version)
  next()
})

router.get('/users', (req, res) => {
  if (req.apiVersion >= 2) {
    return res.json(formatUsersV2(users))
  }
  return res.json(formatUsersV1(users))
})
```

### Deprecation Headers

```typescript
// Middleware for deprecated endpoints
function deprecate(sunsetDate: string, link?: string) {
  return (_req: Request, res: Response, next: NextFunction) => {
    res.setHeader('Deprecation', 'true')
    res.setHeader('Sunset', sunsetDate)
    if (link) res.setHeader('Link', `<${link}>; rel="successor-version"`)
    next()
  }
}

// Usage
v1Router.get('/users', deprecate('2025-12-31', '/api/v2/users'), listUsersV1)
```

---

## Pagination Patterns

### Offset Pagination

```typescript
interface OffsetPaginationQuery {
  page?: number   // 1-indexed
  limit?: number
}

interface PaginatedResponse<T> {
  data: T[]
  pagination: {
    page: number
    limit: number
    total: number
    totalPages: number
    hasNext: boolean
    hasPrev: boolean
  }
}

async function paginate<T>(
  query: OffsetPaginationQuery,
  countFn: () => Promise<number>,
  findFn: (skip: number, take: number) => Promise<T[]>
): Promise<PaginatedResponse<T>> {
  const page = Math.max(1, query.page ?? 1)
  const limit = Math.min(100, query.limit ?? 20)
  const skip = (page - 1) * limit

  const [data, total] = await Promise.all([findFn(skip, limit), countFn()])
  const totalPages = Math.ceil(total / limit)

  return {
    data,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    },
  }
}
```

### Cursor-Based Pagination

Better for real-time data where rows can be inserted between pages. Uses a stable cursor (usually last item's ID or timestamp).

```typescript
interface CursorPaginationQuery {
  after?: string  // opaque cursor (base64-encoded)
  limit?: number
}

interface CursorPaginatedResponse<T> {
  data: T[]
  pageInfo: {
    hasNextPage: boolean
    endCursor: string | null
  }
}

function encodeCursor(value: string): string {
  return Buffer.from(value).toString('base64url')
}

function decodeCursor(cursor: string): string {
  return Buffer.from(cursor, 'base64url').toString('utf8')
}

// In repository
async findUsersAfterCursor(
  afterCursor: string | undefined,
  limit: number
): Promise<User[]> {
  const where = afterCursor
    ? { id: { gt: decodeCursor(afterCursor) } }
    : {}

  return db.user.findMany({
    where,
    orderBy: { id: 'asc' },
    take: limit + 1, // fetch one extra to determine hasNextPage
  })
}

// In service
async getUsers(query: CursorPaginationQuery): Promise<CursorPaginatedResponse<User>> {
  const limit = Math.min(100, query.limit ?? 20)
  const rows = await this.repo.findUsersAfterCursor(query.after, limit)

  const hasNextPage = rows.length > limit
  const data = hasNextPage ? rows.slice(0, -1) : rows
  const lastItem = data.at(-1)

  return {
    data,
    pageInfo: {
      hasNextPage,
      endCursor: lastItem ? encodeCursor(lastItem.id) : null,
    },
  }
}
```

**When to use each:**
- Offset: admin tables, reports, known total count needed, no real-time inserts
- Cursor: feeds, activity streams, any list with frequent inserts

---

## GraphQL DataLoader (N+1 Prevention)

The N+1 problem: fetching a list of posts, then making one DB query per post to load its author.

```bash
pnpm add dataloader
```

```typescript
// loaders/user.loader.ts
import DataLoader from 'dataloader'
import { userRepository } from './user.repository'

// Batch function: receives array of keys, returns array of values (same order)
async function batchUsers(ids: readonly string[]): Promise<(User | Error)[]> {
  const users = await userRepository.findByIds([...ids])
  const userMap = new Map(users.map((u) => [u.id, u]))

  // IMPORTANT: return results in the same order as input ids
  return ids.map((id) => userMap.get(id) ?? new Error(`User ${id} not found`))
}

export function createUserLoader(): DataLoader<string, User> {
  return new DataLoader(batchUsers, {
    cache: true,         // per-request cache (default true)
    maxBatchSize: 100,   // limit batch size
  })
}

// context.ts — create loaders per request (NOT global — they cache per request)
export interface GraphQLContext {
  userLoader: DataLoader<string, User>
  currentUser: User | null
}

export function createContext(): GraphQLContext {
  return {
    userLoader: createUserLoader(),
    currentUser: null,
  }
}

// resolver using DataLoader
const resolvers = {
  Post: {
    author: (post: Post, _args: unknown, ctx: GraphQLContext) => {
      // 100 posts → 1 batched DB query instead of 100
      return ctx.userLoader.load(post.authorId)
    },
  },
}
```

Multiple DataLoader for related data:
```typescript
// Load by non-ID fields using prime()
async function batchUsersByEmail(
  emails: readonly string[]
): Promise<(User | Error)[]> {
  const users = await userRepository.findByEmails([...emails])
  const emailMap = new Map(users.map((u) => [u.email, u]))
  return emails.map((e) => emailMap.get(e) ?? new Error(`User ${e} not found`))
}
```

---

## Error Response Standardization

### RFC 7807 Problem Details

```typescript
// problem-details.ts
interface ProblemDetails {
  type: string        // URI identifying the problem type
  title: string       // Human-readable summary
  status: number      // HTTP status code
  detail?: string     // Human-readable explanation
  instance?: string   // URI identifying this specific occurrence
  [key: string]: unknown // Extension members
}

function problem(
  status: number,
  title: string,
  detail?: string,
  extensions?: Record<string, unknown>
): ProblemDetails {
  return {
    type: `https://api.example.com/errors/${title.toLowerCase().replace(/\s+/g, '-')}`,
    title,
    status,
    detail,
    ...extensions,
  }
}

// Error code registry
export const Problems = {
  NotFound: (resource: string) =>
    problem(404, 'Not Found', `${resource} was not found`),

  ValidationError: (errors: Record<string, string[]>) =>
    problem(422, 'Validation Error', 'Input validation failed', { errors }),

  Unauthorized: () =>
    problem(401, 'Unauthorized', 'Authentication is required'),

  Forbidden: (action?: string) =>
    problem(403, 'Forbidden', action ? `You cannot ${action}` : 'Access denied'),

  Conflict: (detail: string) =>
    problem(409, 'Conflict', detail),

  TooManyRequests: (retryAfter: number) =>
    problem(429, 'Too Many Requests', 'Rate limit exceeded', { retryAfter }),
} as const

// Global error handler in Express
app.use((err: unknown, req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof AppError) {
    const pd = problem(err.statusCode, err.message, err.detail)
    return res.status(err.statusCode)
      .contentType('application/problem+json')
      .json(pd)
  }

  console.error(err)
  const pd = problem(500, 'Internal Server Error')
  res.status(500).contentType('application/problem+json').json(pd)
})
```

### Consistent Envelope Pattern (Alternative)

```typescript
// Some APIs prefer a consistent envelope for all responses
interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: {
    code: string
    message: string
    details?: unknown
  }
  meta?: {
    page?: number
    total?: number
    requestId?: string
  }
}

// Success helper
function ok<T>(data: T, meta?: ApiResponse<T>['meta']): ApiResponse<T> {
  return { success: true, data, meta }
}

// Error helper
function fail(code: string, message: string, details?: unknown): ApiResponse<never> {
  return { success: false, error: { code, message, details } }
}

// Usage
res.json(ok(users, { page: 1, total: 42 }))
res.status(404).json(fail('USER_NOT_FOUND', 'User not found'))
```

Choose RFC 7807 for new APIs (standards-compliant). Use envelope pattern for consistency with legacy systems or when clients prefer a uniform structure.
