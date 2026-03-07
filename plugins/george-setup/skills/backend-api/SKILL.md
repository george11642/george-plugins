---
name: backend-api
description: Backend API design, architecture, and production implementation skill. Triggers on API, REST, GraphQL, microservices, event-driven, message queue, RabbitMQ, Kafka, gRPC, WebSocket, OpenAPI, Swagger, authentication, OAuth, JWT, refresh tokens, rate limiting, caching, Redis, middleware, load balancing, service mesh, API gateway, versioning, pagination, CORS, webhook, SSE, server-sent events, health check, circuit breaker, endpoint, route, controller, serializer, idempotency, backpressure, saga, CQRS, event sourcing, dead letter queue, schema stitching, federation, Express.js, Fastify, dependency injection, DI container, Zod validation, asyncHandler, helmet, connection pooling, transaction management, bcrypt, password hashing, api-security, OAuth 2.0, PKCE, serverless API routes, EAS Hosting, Cloudflare Workers, layered architecture, repository pattern, service layer, error handler, rate limiter, sliding window, token bucket, SQL injection, input sanitization, secrets management, HMAC, signature verification, webhook signature, idempotency key, replay attack, consumer group, partition key, dead letter topic, outbox pattern, schema registry, Avro, Protobuf, fanout exchange, direct exchange, topic exchange, DLX, DLQ, publisher confirms, leaky bucket, adaptive rate limiting, oasdiff, openapi-typescript, Prism mock server, Sunset header, Deprecation header, SDK generation, openapi-generator, swagger-jsdoc, swagger-ui-express, @fastify/swagger, breaking change detection
---

# Backend API Skill

## Task Router

| Domain | Reference File | When to Use |
|--------|---------------|-------------|
| REST API Design | `references/rest-design.md` | URL structure, status codes, pagination, versioning, HATEOAS |
| GraphQL | `references/graphql.md` | Schema design, resolvers, DataLoader, subscriptions, federation |
| Microservices | `references/microservices.md` | Service boundaries, communication, saga, CQRS, deployment |
| Messaging & Events | `references/messaging.md` | Kafka, RabbitMQ, event sourcing, dead letter queues |
| Message Queue Patterns | `references/message-queue-patterns.md` | KafkaJS setup, consumer groups, offset management, DLT, RabbitMQ exchanges, DLX, outbox pattern, saga orchestration, consumer lag monitoring |
| Node.js Implementation | `references/nodejs-patterns.md` | Express.js/Fastify setup, layered architecture, DI container, middleware, asyncHandler, Zod validation, error classes, connection pooling, transactions, Redis caching |
| Serverless API Routes | `references/serverless-api-routes.md` | Expo Router `+api.ts` routes, EAS Hosting, Cloudflare Workers, Web Crypto, Turso/Neon/PlanetScale, webhooks |
| API Security | `references/api-security.md` | JWT sign/verify/rotate, OAuth 2.0 + PKCE, API keys, bcrypt, rate limiting strategies, input validation, SQL injection, CORS, helmet, secrets management |
| API Documentation | `references/api-documentation.md` | OpenAPI 3.1 YAML structure, components/schemas, security schemes, swagger-jsdoc, @fastify/swagger, openapi-typescript, oasdiff, Prism mock server, SDK generation, deprecation headers |
| Webhook Patterns | `references/webhook-patterns.md` | HMAC-SHA256 signature verification, idempotency keys, replay attack prevention, retry backoff, fan-out, subscription management, circuit breaker, Express handler |
| Rate Limiting Strategies | `references/rate-limiting-strategies.md` | Token bucket, sliding window, fixed window, leaky bucket, Redis Lua scripts, express-rate-limit, tiered plans, adaptive limits, DDoS mitigation, circuit breaker interaction |
| Infrastructure | All references | Load balancing, caching, service mesh, API gateway |

## Before Starting

Ask these questions before writing any code:

1. **What protocol?** REST, GraphQL, gRPC, or hybrid? Each has different strengths — REST for CRUD-heavy public APIs, GraphQL for flexible client queries, gRPC for internal service-to-service.
2. **Sync or async?** Request-response or event-driven? If a request triggers work that takes >500ms, consider async with webhooks or polling.
3. **Scale requirements?** Expected RPS, data volume, latency budget. These determine whether you need caching, message queues, or read replicas.
4. **Who consumes this?** Public developers, internal services, mobile clients? This drives auth strategy, versioning approach, and documentation depth.
5. **Data consistency?** Strong consistency (SQL + transactions) or eventual consistency (events + sagas)? Never mix without explicit justification.
6. **Runtime?** Node.js server (Express/Fastify), or serverless edge (Cloudflare Workers / EAS Hosting)? Serverless constrains available APIs — no fs, no persistent connections, 30s CPU limit.

## Quick Reference — REST Conventions

```
GET    /resources          → List (200, paginated)
GET    /resources/:id      → Read (200 or 404)
POST   /resources          → Create (201 + Location header)
PUT    /resources/:id      → Full replace (200 or 404)
PATCH  /resources/:id      → Partial update (200 or 404)
DELETE /resources/:id      → Remove (204 or 404)
```

### Status Codes Cheat Sheet

| Code | Meaning | Use When |
|------|---------|----------|
| 200 | OK | Successful read/update |
| 201 | Created | Successful resource creation |
| 204 | No Content | Successful delete |
| 400 | Bad Request | Malformed input, validation failure |
| 401 | Unauthorized | Missing or invalid credentials |
| 403 | Forbidden | Valid credentials, insufficient permissions |
| 404 | Not Found | Resource does not exist |
| 409 | Conflict | Duplicate resource, version conflict |
| 422 | Unprocessable | Syntactically valid but semantically wrong |
| 429 | Too Many Requests | Rate limit exceeded (include Retry-After) |
| 500 | Internal Error | Unhandled server failure |
| 502 | Bad Gateway | Upstream service failure |
| 503 | Service Unavailable | Planned maintenance, overload |

## Decision Trees

### REST vs GraphQL vs gRPC

```
Is this service-to-service with high throughput?
  YES → gRPC (binary protocol, streaming, codegen)
  NO  → Do clients need flexible queries across nested resources?
    YES → GraphQL (single endpoint, client-driven shape)
    NO  → REST (simple CRUD, broad tooling, cacheable)
```

### Monolith vs Microservices

```
Team size < 5 AND single deployment target?
  YES → Modular monolith (domain modules, shared DB, one deploy)
  NO  → Do domains have independent scaling/deployment needs?
    YES → Microservices (separate repos, own DBs, async comms)
    NO  → Modular monolith with extraction plan
```

### Sync vs Async Communication

```
Does the caller need an immediate response?
  YES → Sync (HTTP/gRPC). Add circuit breaker + timeout.
  NO  → Is ordering important?
    YES → Kafka (partitioned, ordered log)
    NO  → RabbitMQ (flexible routing, DLQ, priorities)
```

### Node.js Server vs Serverless Edge

```
Need Node.js APIs (fs, native modules, long connections)?
  YES → Express/Fastify on a server or container
  NO  → Is this an Expo app or Cloudflare-first workload?
    YES → Expo Router +api.ts routes (EAS Hosting / Cloudflare Workers)
    NO  → Either works; prefer server for complex stateful logic
```

## Core Principles

1. **API-first design.** Write the OpenAPI spec before code. Why: it forces you to think about the contract, catches design issues early, and enables parallel frontend/backend work.
2. **Backwards compatibility.** Never remove or rename fields in a response. Add new fields, deprecate old ones, version breaking changes. Why: deployed clients break silently.
3. **Idempotency.** Make POST/PUT/DELETE safe to retry. Use idempotency keys for creation. Why: networks fail, clients retry, and duplicate side effects corrupt data.
4. **Fail explicitly.** Return structured error bodies with machine-readable codes. Never return 200 with `{"error": "..."}`. Why: clients need reliable error detection without parsing bodies.
5. **Least privilege.** Every endpoint enforces auth + authz. Default deny. Why: one unprotected internal endpoint becomes a breach vector.
6. **Observability.** Emit structured logs, metrics, and traces from day one. Correlate with request IDs. Why: you cannot debug production without them.
7. **Validate all inputs.** Use Zod or Joi schemas on every request body, query param, and path param. Coerce types, set limits, strip unknown fields. Why: malformed input is the most common bug vector.

## Anti-Patterns

- **N+1 queries.** Fetching a list then querying each item individually. Fix: use JOINs, DataLoader, or batch endpoints.
- **Chatty APIs.** Requiring 5+ calls to render one screen. Fix: aggregate endpoints, BFF pattern, or GraphQL.
- **Missing pagination.** Returning unbounded lists. Fix: always paginate with cursor-based pagination for large datasets.
- **Leaking internals.** Exposing database IDs, stack traces, or internal service names. Fix: use UUIDs, generic error messages, response serializers.
- **God service.** One microservice handling 10+ domains. Fix: decompose along bounded contexts.
- **Synchronous chains.** Service A calls B calls C calls D synchronously. Fix: use events for non-critical paths, or collapse into fewer services.
- **No circuit breaker.** Cascading failures when a dependency goes down. Fix: circuit breaker + fallback + timeout on every external call.
- **Versioning by URL AND header.** Pick one strategy and stick with it. URL versioning (`/v2/`) is simpler. Header versioning is cleaner but harder to test.
- **SQL string interpolation.** Embedding user input directly in SQL strings. Fix: always use parameterized queries (`$1`, `?`). No exceptions.
- **Hardcoded secrets.** API keys or JWT secrets in source code. Fix: always read from environment variables; validate at startup with Zod.
- **Missing asyncHandler.** Async route handlers without try/catch or asyncHandler wrapper. Fix: wrap every async Express route — unhandled promise rejections crash the process.
- **Short-lived only JWT.** Issuing only access tokens with no refresh flow. Fix: access tokens expire in 15m, refresh tokens in 7d with rotation on use.
