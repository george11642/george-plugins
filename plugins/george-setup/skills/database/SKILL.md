---
name: database
description: Database engineering skill covering SQL, PostgreSQL, MySQL, SQLite, MongoDB, Redis, DynamoDB, query optimization, indexing, migrations, schema design, ORM, Prisma, Drizzle, SQLAlchemy, TypeORM, Sequelize, normalization, denormalization, BCNF, transactions, ACID, connection pooling, replication, sharding, backup, restore, stored procedures, views, triggers, foreign keys, joins, aggregation, full-text search, vector database, pgvector, Pinecone, data modeling, database performance, slow queries, N+1, query planner, EXPLAIN, vacuum, partitioning, database migration, schema evolution, database design, ERD, cardinality, composite key, repository pattern, Alembic, Flyway, zero-downtime migration, data backfill, audit trail, soft delete, multi-tenant, row level security, SCD, slowly changing dimension, star schema, temporal data, event sourcing, data warehouse, B-tree, GIN, BRIN, index bloat, streaming replication, logical replication, sharding, CockroachDB, EXPLAIN ANALYZE, PgBouncer, transaction isolation, MVCC, deadlock, serialization failure, pg_stat_statements, cache hit ratio, Prometheus postgres_exporter, keyset pagination, index selectivity, fill factor, HOT update, replication slot, Patroni, pg_auto_failover, Debezium, CDC, connection leak, idle in transaction, advisory lock, SKIP LOCKED, write skew, serializable snapshot isolation, auto_explain, pgBadger
---

# Database Skill

## Task Router

| Domain | Reference File | When to Use |
|--------|---------------|-------------|
| SQL optimization | `references/sql-optimization.md` | EXPLAIN analysis, slow queries, index strategy, CTEs, window functions |
| PostgreSQL | `references/postgresql.md` | PG-specific features, JSONB, full-text search, partitioning, pgvector |
| NoSQL | `references/nosql.md` | MongoDB, Redis, DynamoDB, document/key-value/wide-column patterns |
| ORM patterns | `references/orm-patterns.md` | Prisma, Drizzle, SQLAlchemy, TypeORM — when to drop to raw SQL |
| Migrations | `references/migrations.md` | Schema changes, zero-downtime deploys, rollbacks, data backfills |
| Data modeling | `references/data-modeling.md` | Schema design, normalization, relationships, audit trails |
| Indexing deep dive | `references/indexing-deep-dive.md` | B-tree, GIN, BRIN, GiST, SP-GiST, partial indexes, expression indexes, fill factor, HOT updates, index bloat, REINDEX CONCURRENTLY, index selectivity, covering indexes |
| Replication & sharding | `references/replication-sharding.md` | Streaming replication, logical replication, replication slots, Patroni, pg_auto_failover, CDC, Debezium, read replicas, range/hash/directory sharding, hot spot avoidance, CockroachDB, YugabyteDB, re-sharding |
| Query optimization case studies | `references/query-optimization-case-studies.md` | EXPLAIN ANALYZE deep dive, N+1 queries, missing FK indexes, query rewriting, keyset pagination, pg_stat_statements, plan regression, cost model tuning |
| Connection pooling | `references/connection-pooling-operations.md` | PgBouncer modes/config/sizing, pool size formula, connection leaks, idle in transaction, multi-tenant pooling, RDS Proxy, Supavisor |
| Transactions & concurrency | `references/transactions-concurrency.md` | Isolation levels, MVCC, dead tuples, deadlock avoidance, SELECT FOR UPDATE, SKIP LOCKED, advisory locks, serialization failure retry, optimistic vs pessimistic locking, write skew |
| Monitoring & observability | `references/monitoring-observability.md` | pg_stat_statements, cache hit ratio, dead tuple ratio, replication lag, slow query log, Prometheus postgres_exporter, Grafana dashboards, auto_explain, pgBadger, capacity planning |

## Before Starting

Answer these questions before writing any database code:

1. **What database engine?** PostgreSQL, MySQL, SQLite, MongoDB, Redis, DynamoDB — each has different strengths.
2. **Read-heavy or write-heavy?** Read-heavy favors denormalization and caching. Write-heavy favors normalization and append-only patterns.
3. **What scale?** Single node < 1M rows needs no heroics. 10M+ rows needs indexing strategy. 100M+ needs partitioning/sharding.
4. **What consistency model?** Strong consistency (ACID) vs eventual consistency — pick based on business requirements.
5. **Who runs migrations?** CI/CD pipeline, manual DBA approval, or ORM auto-sync — determines migration tooling.

## Quick Reference

### Index Types
| Type | Use Case | Engine |
|------|----------|--------|
| B-tree | Default, range queries, sorting | All |
| Hash | Exact equality only | PG, MySQL (Memory) |
| GIN | JSONB, arrays, full-text search | PG |
| GiST | Geometric, range types, proximity | PG |
| BRIN | Large sequential tables (timestamps) | PG |
| Partial | Filter on subset of rows | PG |
| Covering | Include columns to avoid table lookup | PG, MySQL 8+ |

### Common EXPLAIN Flags
| Flag | Meaning | Action |
|------|---------|--------|
| Seq Scan | Full table scan | Add index or check WHERE clause |
| Index Scan | Using index | Good — verify selectivity |
| Bitmap Heap Scan | Multiple index matches | Normal for OR conditions |
| Nested Loop | Row-by-row join | Fine for small sets, bad for large |
| Hash Join | Hash-based join | Good for large equi-joins |
| Sort | In-memory or disk sort | Add index matching ORDER BY |

### SQL Cheat Sheet
```sql
-- Upsert (PostgreSQL)
INSERT INTO t (id, val) VALUES (1, 'x')
ON CONFLICT (id) DO UPDATE SET val = EXCLUDED.val;

-- Window function: running total
SELECT *, SUM(amount) OVER (PARTITION BY user_id ORDER BY created_at) AS running_total
FROM orders;

-- CTE with recursive
WITH RECURSIVE tree AS (
  SELECT id, parent_id, name, 0 AS depth FROM categories WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.parent_id, c.name, t.depth + 1 FROM categories c JOIN tree t ON c.parent_id = t.id
) SELECT * FROM tree;
```

## Decision Trees

### SQL vs NoSQL
- **Default to SQL** unless you have a specific reason not to.
- Use **MongoDB** when: schema is truly unpredictable, document-oriented access, rapid prototyping with evolving schema.
- Use **Redis** when: caching, session storage, rate limiting, pub/sub, leaderboards.
- Use **DynamoDB** when: AWS-native, single-digit ms latency at any scale, known access patterns upfront.

### Which SQL Engine
- **PostgreSQL**: Default choice. Best extension ecosystem, JSONB, full-text search, pgvector.
- **MySQL**: Legacy apps, WordPress, simple replication. Use 8.0+ for CTEs and window functions.
- **SQLite**: Embedded, local-first apps, testing, single-writer workloads. Surprisingly powerful at scale with WAL mode.

### Which ORM
- **Prisma**: TypeScript projects, excellent DX, schema-first, auto-migrations. Avoid for complex raw SQL needs.
- **Drizzle**: TypeScript projects wanting SQL-like syntax, lighter weight, better raw SQL escape hatch.
- **SQLAlchemy**: Python gold standard. Use Core for performance, ORM for productivity.
- **TypeORM**: Legacy TS projects. Prefer Prisma or Drizzle for new projects.

## Core Principles

1. **Normalize first, denormalize for measured performance problems.** Start at 3NF. Only denormalize when you have query metrics proving a join is the bottleneck.
2. **Every query must have an index strategy.** Run EXPLAIN on every query that touches production. No exceptions.
3. **Migrations are code.** Version-control every schema change. Never modify production schemas by hand.
4. **Transactions protect invariants.** Use transactions for any multi-statement operation that must be atomic. Set appropriate isolation levels.
5. **Connection pooling is mandatory in production.** Use PgBouncer, RDS Proxy, or ORM-level pooling. Never open unbounded connections.
6. **Backups are worthless until tested.** Schedule regular restore drills. Point-in-time recovery > daily dumps.
7. **Prefer append-only patterns for audit trails.** Soft deletes + created_at/updated_at on every table. Use triggers or application-level hooks.

## Anti-Patterns

| Anti-Pattern | Why It Hurts | Fix |
|-------------|-------------|-----|
| No indexes on foreign keys | JOIN performance degrades linearly | Add B-tree index on every FK column |
| N+1 queries | 1 query + N child queries = N+1 round trips | Use JOIN, subquery, or ORM eager loading |
| Schema changes without migrations | Drift between environments, unreproducible state | Use migration tool (Prisma Migrate, Alembic, Flyway) |
| SELECT * in production | Fetches unnecessary columns, breaks on schema change | Explicitly list needed columns |
| Missing connection limits | One runaway service exhausts DB connections | Configure pool size, use PgBouncer |
| Storing money as FLOAT | Floating point rounding errors | Use DECIMAL/NUMERIC or integer cents |
| Unbounded queries | No LIMIT on user-facing queries = OOM risk | Always paginate with LIMIT/OFFSET or cursor |
| Mixing DDL and DML in one transaction | Some engines auto-commit on DDL, breaking atomicity | Separate DDL migrations from data migrations |
