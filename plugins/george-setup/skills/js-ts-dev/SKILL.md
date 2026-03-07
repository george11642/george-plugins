---
name: js-ts-dev
description: Use when writing JavaScript, TypeScript, Node.js, Express, Fastify, React, async/await, promises, ES modules, npm, yarn, pnpm, Vite, esbuild, Webpack, turbopack, Turbopack, ESLint, Prettier, Jest, Vitest, Playwright, advanced types, generics, GraphQL, REST API design, OpenAPI, Swagger, swagger-jsdoc, debugging, snapshot testing, test fixtures, faker, Proxy, Reflect, Symbol, WeakMap, WeakSet, private fields, tagged templates, async generators, WebSocket, Socket.io, BullMQ, job queues, GraphQL schema, DataLoader, pagination, cursor pagination, microservices, AbortController, RabbitMQ, Kafka, circuit breaker, React Testing Library, userEvent, MSW, mock service worker, renderHook, Redis, ioredis, caching, cache invalidation, pub/sub, dependency injection, DI container, tsyringe, inversify, tsconfig, noUncheckedIndexedAccess, exactOptionalPropertyTypes, satisfies, path aliases, incremental build, vite.config.ts, HMR, library mode, tree-shaking, or any JS/TS work.
---

# JavaScript & TypeScript Development

Unified skill for all JS/TS work: types, backends, testing, modern patterns, build tools, and API design.

## Task Router

| Domain | Reference |
|--------|-----------|
| TypeScript types, generics, mapped/conditional types, type guards | `references/advanced-types.md` |
| Node.js, Express, Fastify, middleware, auth, DB, caching | `references/node-backend.md` |
| WebSocket, Socket.io, BullMQ, job queues, GraphQL schema, DataLoader, microservices, AbortController, RabbitMQ, Kafka | `references/advanced-backend.md` |
| Jest, Vitest, Playwright, mocking, integration, E2E, coverage | `references/testing.md` |
| Snapshot testing, test fixtures, faker, testcontainers, MSW, coverage thresholds | `references/testing-advanced.md` |
| ES6+, async/await, FP, destructuring, modules, generators | `references/modern-js.md` |
| Proxy, Reflect, Symbol, WeakMap, WeakSet, private class fields, tagged templates, async generators | `references/advanced-js-patterns.md` |
| Build tools, bundlers, package managers, linting | This file - Build & Tooling |
| REST, GraphQL, OpenAPI | This file - API Design |
| Debugging, profiling, TS errors | This file - Debugging |
| Vite config, vite.config.ts, esbuild, Turbopack, tsconfig strict mode, noUncheckedIndexedAccess, ESLint flat config | `references/build-tools-modern.md` |
| Dependency injection, DI container, tsyringe, inversify, manual DI, composition root, interface injection | `references/dependency-injection.md` |
| React Testing Library, userEvent, MSW, mock service worker, screen queries, renderHook, Next.js component testing | `references/testing-library-react.md` |
| Redis, ioredis, caching, CacheService, @Cacheable decorator, cache invalidation, pub/sub, session storage | `references/caching-redis.md` |
| OpenAPI, Swagger, swagger-jsdoc, API versioning, pagination, cursor pagination, DataLoader, error responses, RFC 7807 | `references/api-design-patterns.md` |

## TypeScript Advanced Types

- **Generics**: `<T extends HasLength>` for constraints, multiple params `<T, U>`
- **Conditional**: `T extends string ? true : false`, `infer` for extraction
- **Mapped**: `{ [P in keyof T]: T[P] }`, key remapping with `as`, value filtering
- **Template literal**: `\`on${Capitalize<EventName>}\``, recursive path types
- **Utility types**: `Partial`, `Required`, `Readonly`, `Pick`, `Omit`, `Record`, `ReturnType`, `Parameters`
- **Patterns**: Type-safe event emitter, API client, builder pattern, discriminated unions, deep readonly/partial, form validation
- **Guards**: `value is string` predicates, `asserts` functions, composable guards
- **Best practices**: `unknown` over `any`, `interface` for objects, `type` for unions, strict mode, `const` assertions
- See `references/advanced-types.md` for code examples

## Node.js Backend

- **Frameworks**: Express (middleware-based, helmet/cors/compression) or Fastify (high perf, schema validation, Pino)
- **Architecture**: Controllers (HTTP) -> Services (logic) -> Repositories (data). DI container for wiring
- **Middleware**: JWT auth + role-based authorize, Zod validation, Redis-backed rate limiting, structured logging
- **Errors**: `AppError` hierarchy (400-409), global handler, `asyncHandler` wrapper
- **Database**: PostgreSQL connection pool, parameterized queries, transaction pattern, Mongoose for MongoDB
- **Caching**: Redis `CacheService` with get/set/invalidate, `@Cacheable(ttl)` decorator
- **Auth**: JWT access (15m) + refresh (7d) tokens, bcrypt hashing, token refresh endpoint
- **Ops**: Graceful shutdown (SIGTERM/SIGINT), health checks, connection pooling, API response format
- See `references/node-backend.md` for code examples

## Testing

- **Frameworks**: Jest (`ts-jest` preset), Vitest (Vite-native, `vi.fn/mock/spyOn`), Playwright (E2E)
- **Unit**: Pure functions (happy/edge/error), classes with `beforeEach`, async with `rejects.toThrow()`
- **Mocking**: Module mocks, DI interface mocks, spies, partial mocks, return sequences, timer/date mocking
- **Integration**: `supertest` with real app, DB setup/teardown, auth flow tests
- **E2E**: Playwright `test()` with `page.goto/click/fill`, `expect(page).toHaveURL()`
- **Frontend**: `@testing-library/react` (render/screen/fireEvent), `renderHook` + `act`, `waitFor` async
- **Patterns**: AAA, test factories with faker, 80%+ coverage, describe nesting, behavior over implementation
- See `references/testing.md` for code examples

## Modern JavaScript (ES6+)

- **Core**: Arrow functions (lexical `this`), destructuring (object/array/nested/defaults), spread/rest, template literals
- **Modules**: Named/default exports, dynamic `import()`, conditional loading, tree-shakeable
- **Async**: `Promise.all/allSettled/race/any`, async/await, retry with backoff, timeout wrapper, error tuples
- **FP**: Array methods (map/filter/reduce/flatMap), currying, partial application, memoization, pipe/compose
- **Immutability**: Spread for updates, `structuredClone` for deep copy, `Object.freeze`, never mutate inputs
- **Generators**: `function*` with `yield`, async generators for pagination, lazy pipelines (map/filter/take)
- **Operators**: Optional chaining `?.`, nullish coalescing `??`, logical assignment `??=`/`||=`/`&&=`
- **Performance**: `debounce`, `throttle`, `AbortController` for cancellable fetch
- See `references/modern-js.md` for code examples

## Build Tools & Package Management

### Bundlers

- **Vite**: Dev server with HMR, Rollup-based production builds. Default choice for new projects
- **esbuild**: Extremely fast, use for libraries and CLI tools. Limited plugin ecosystem
- **Webpack**: Mature ecosystem, complex config. Use when Vite/esbuild insufficient
- **Turbopack**: Next.js integrated, Rust-based. Use only within Next.js

### Package Managers

- **npm**: Default, widest compatibility. `package-lock.json`
- **pnpm**: Fastest, strict deps via symlinks. Preferred for monorepos. `pnpm-lock.yaml`
- **yarn**: Berry (v4) with PnP or node_modules. `yarn.lock`
- Always pin exact versions in production (`--save-exact`). Use `engines` field

### Linting & Formatting

- **ESLint**: Flat config (`eslint.config.js`). Extend `@typescript-eslint` for TS projects
- **Prettier**: `.prettierrc` with `semi`, `singleQuote`, `trailingComma`
- **lint-staged + husky**: Pre-commit hooks for lint/format enforcement

## API Design

### REST

- Nouns for resources: `/users`, `/users/:id`, `/users/:id/posts`
- HTTP verbs: GET (read), POST (create), PUT (replace), PATCH (update), DELETE
- Status codes: 200, 201, 204, 400, 401, 403, 404, 409, 422, 429, 500
- Pagination: `?page=1&limit=20` with response metadata. Versioning: URL prefix `/v1/`

### GraphQL

- Schema-first (SDL) or code-first (`type-graphql`). DataLoader for N+1 prevention
- Implement depth/complexity limiting to prevent abuse queries

### OpenAPI

- Generate from code with `swagger-jsdoc` or write spec-first with `openapi-generator`
- Use for client SDK generation, docs, and contract testing

## Debugging

### Node.js

- `--inspect` flag + Chrome DevTools or VS Code debugger
- `console.time()`/`timeEnd()` for quick measurement, `--prof` for CPU, `--heap-prof` for memory

### Common TypeScript Errors

- **"not assignable"**: Missing props, wrong types, missing `| undefined`
- **"property does not exist"**: Use type guard, discriminated union, or optional chaining
- **"cannot find module"**: Check `tsconfig.json` paths, `moduleResolution`, `types` array

### Common Pitfalls

- Forgetting `await` on async calls (returns Promise, not value)
- `==` vs `===` (always strict equality)
- `this` binding in callbacks (use arrow functions)
- Floating promises without `.catch()` or try/catch
