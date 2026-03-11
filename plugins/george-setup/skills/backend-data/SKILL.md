---
name: backend-data
description: Use for any server-side API or data persistence work. Triggers on REST endpoints, GraphQL resolvers, DataLoader, Node.js, Express, Fastify, API design, pagination, filtering, sorting, databases, SQL, PostgreSQL, indexes, EXPLAIN ANALYZE, query optimization, Prisma, Drizzle, TypeORM, SQLAlchemy, ORM, N+1 queries, migrations, Alembic, schema design, data modeling, normalization, JWT, OAuth, authentication, authorization, rate limiting, Redis, caching, message queues, BullMQ, Kafka, RabbitMQ, webhooks, idempotency, signatures, microservices, multi-tenant, row-level security.
---

# Backend & Data

Layer 2 domain skill for all server-side development and data persistence. Routes to reference files and Layer 3 atomic skills by task type.

## Task Router

| Task Pattern | Reference | Layer 3 Skills |
|---|---|---|
| REST API design, URL structure, status codes | `references/rest-graphql.md` | — |
| GraphQL schema, resolvers, DataLoader | `references/rest-graphql.md` | — |
| Node.js, Express, Fastify, middleware | `references/nodejs-patterns.md` | — |
| SQL optimization, EXPLAIN, query tuning | `references/sql-optimization.md` | — |
| ORM (Prisma, Drizzle, TypeORM, SQLAlchemy) | `references/orm-patterns.md` | — |
| API auth, JWT, OAuth, rate limiting | `references/api-security.md` | security-deep, auth-clerk |
| Microservices, message queues, Kafka, RabbitMQ | `references/microservices.md` | — |
| Database migrations, schema changes | `references/migrations.md` | — |
| Data modeling, normalization, schema design | `references/data-modeling.md` | — |
| Webhooks, signatures, idempotency | `references/webhooks.md` | — |

## When to Use

Activate for any task involving:
- API design or implementation (REST, GraphQL, gRPC)
- Database queries, schema design, or migrations
- Authentication and authorization patterns
- Server-side Node.js with Express or Fastify
- Microservices architecture or message queues
- Caching strategies (Redis)
- Webhook implementation or consumption

## Layer 3 Skills (Atomic)

- **db-convex** — Convex database operations and schema management
- **db-supabase** — Supabase database operations
- **auth-clerk** — Authentication with Clerk
- **payments-stripe** — Stripe payment integration

## Quick Decision Trees

### Protocol Choice
```
Service-to-service, high throughput? → gRPC
Flexible client queries, nested data? → GraphQL
Simple CRUD, broad tooling? → REST (default)
```

### Database Choice
```
Default → PostgreSQL (JSONB, full-text search, pgvector)
Embedded/local-first → SQLite (WAL mode)
Caching/sessions → Redis
Document store, evolving schema → MongoDB
AWS-native, single-digit ms → DynamoDB
```

### ORM Choice
```
TypeScript, great DX? → Prisma (schema-first)
TypeScript, SQL-like syntax? → Drizzle (lighter)
Python? → SQLAlchemy
Complex raw SQL needs? → Drop to query builder
```
