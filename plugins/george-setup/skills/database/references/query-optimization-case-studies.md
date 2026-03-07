# Query Optimization Case Studies

## EXPLAIN ANALYZE Deep Dive

### Basic Usage
```sql
-- Always use ANALYZE for actual execution data (runs the query!)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT * FROM orders WHERE user_id = 123;

-- For destructive queries: wrap in a transaction and rollback
BEGIN;
EXPLAIN ANALYZE DELETE FROM orders WHERE status = 'cancelled';
ROLLBACK;
```

### Reading EXPLAIN Output

```
Seq Scan on orders  (cost=0.00..4521.00 rows=1 width=128)
                     ^           ^        ^     ^     ^
                     startup     total    est   est   row
                     cost        cost     rows  width size
                    (actual time=0.021..45.12 rows=1 loops=1)
                                 ^         ^     ^
                                 first row  last row  how many
                                 ms        ms        times node ran
```

**Key fields**:
- `cost`: planner's estimated cost (arbitrary units, relative to `seq_page_cost=1.0`)
- `rows`: planner's row estimate — if wildly wrong, run `ANALYZE`
- `actual time`: real milliseconds (startup..total)
- `loops`: times this node was executed (multiply actual time by loops for total)
- `Buffers: hit=N read=M`: N pages from shared_buffers (cache), M from disk

### Node Types and What They Mean

| Node | Meaning | When It's Good/Bad |
|------|---------|-------------------|
| Seq Scan | Full table scan | Good for small tables or > 15% of rows; bad for large selective queries |
| Index Scan | Random access via index | Good; heap fetch per row (random I/O) |
| Index Only Scan | Index covers all needed columns | Best — no heap fetch |
| Bitmap Index Scan | Bitmap of matching pages | Good for OR conditions or moderate selectivity |
| Bitmap Heap Scan | Fetch pages from bitmap | Follows Bitmap Index Scan; fetches in page order |
| Nested Loop | For each outer row, scan inner | Good for small inner sets; catastrophic for large |
| Hash Join | Build hash of inner, probe with outer | Good for large equi-joins; needs memory for hash |
| Merge Join | Sort both sides, merge | Good when both inputs already sorted; costly if sorting needed |
| Sort | In-memory or disk sort | Fine if < `work_mem`; slow if spills to disk |
| Hash | Build hash table | Used in Hash Join; watch for "Batches: N > 1" (spilled to disk) |

### Spotting Problems in EXPLAIN Output

**Row estimate mismatch**:
```
(cost=... rows=1000 ...) (actual ... rows=50000 ...)
```
Planner estimated 1000, got 50000 → stale statistics → run `ANALYZE`.

**Nested Loop on large sets**:
```
Nested Loop  (cost=... rows=50000 ...) (actual loops=50000 ...)
```
50,000 loops on inner relation = sequential scan 50,000 times. Need an index on the join column.

**Sort spilling to disk**:
```
Sort  (actual ... Batches: 4)
```
Sorted in 4 batches (disk spill) → increase `work_mem` for this session:
```sql
SET work_mem = '256MB';
EXPLAIN ANALYZE SELECT ...;
```

**Hash join batches > 1**:
```
Hash  (Batches: 8 Memory Usage: 4096kB)
```
Hash table spilled to disk → increase `work_mem`.

---

## Case Study 1: N+1 Query

### Symptom
Application issues 1 query to get users, then N separate queries for each user's orders.

```python
# ORM code generating N+1
users = db.query("SELECT * FROM users WHERE active = true")
for user in users:
    orders = db.query(f"SELECT * FROM orders WHERE user_id = {user.id}")
    # N queries, one per user
```

**EXPLAIN shows**: 1 Seq Scan on users + N Index Scans on orders.

### Fix: JOIN or Eager Load
```sql
-- Fix 1: JOIN
SELECT u.id, u.name, o.id AS order_id, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.active = true;

-- Fix 2: IN clause (batched fetch)
SELECT * FROM orders
WHERE user_id = ANY(ARRAY[1,2,3,...,N]);
```

**ORM-level fixes**:
```python
# Django
User.objects.filter(active=True).select_related('profile').prefetch_related('orders')

# SQLAlchemy
session.query(User).options(joinedload(User.orders)).filter(User.active == True)

# Prisma
prisma.user.findMany({ where: { active: true }, include: { orders: true } })
```

### Detection
```sql
-- pg_stat_statements: find queries with very high call counts
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
WHERE query LIKE '%orders%'
ORDER BY calls DESC
LIMIT 10;
```

---

## Case Study 2: Missing Index on Foreign Key

### Symptom
```sql
-- Slow query joining large tables
SELECT u.name, count(o.id)
FROM users u
JOIN orders o ON o.user_id = u.id
GROUP BY u.id;
```

EXPLAIN shows high `actual rows` on the inner side of a Nested Loop or Hash Join with no index.

### Detection
```sql
-- Find tables with high sequential scan counts
SELECT relname, seq_scan, seq_tup_read, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > 1000
ORDER BY seq_tup_read DESC;

-- Find foreign keys without indexes (common oversight)
SELECT
  tc.table_name, kcu.column_name,
  ccu.table_name AS foreign_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu USING (constraint_name)
JOIN information_schema.referential_constraints rc USING (constraint_name)
JOIN information_schema.constraint_column_usage ccu ON rc.unique_constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = tc.table_name
      AND indexdef LIKE '%' || kcu.column_name || '%'
  );
```

### Fix
```sql
-- Add index on FK column (non-blocking)
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);
```

---

## Case Study 3: Query Rewriting

### Correlated Subquery → Window Function
```sql
-- SLOW: correlated subquery runs once per row
SELECT id, amount,
  (SELECT sum(amount) FROM orders o2 WHERE o2.user_id = o1.user_id AND o2.id <= o1.id)
FROM orders o1;

-- FAST: window function computes in one pass
SELECT id, amount,
  SUM(amount) OVER (PARTITION BY user_id ORDER BY id) AS running_total
FROM orders;
```

### NOT IN → NOT EXISTS (NULL Safety + Performance)
```sql
-- SLOW and incorrect with NULLs: NOT IN returns NULL if any value in subquery is NULL
SELECT * FROM users
WHERE id NOT IN (SELECT user_id FROM banned_users);

-- FAST and correct: NOT EXISTS handles NULLs properly
SELECT * FROM users u
WHERE NOT EXISTS (SELECT 1 FROM banned_users b WHERE b.user_id = u.id);

-- Alternative: LEFT JOIN ... IS NULL
SELECT u.*
FROM users u
LEFT JOIN banned_users b ON b.user_id = u.id
WHERE b.user_id IS NULL;
```

### OR Conditions → UNION ALL
```sql
-- SLOW: OR prevents index usage on either condition
SELECT * FROM events
WHERE type = 'login' OR type = 'logout';

-- FAST: each branch uses its own index
SELECT * FROM events WHERE type = 'login'
UNION ALL
SELECT * FROM events WHERE type = 'logout';
```

### COUNT(*) Optimization
```sql
-- For approximate count on large tables (much faster)
SELECT reltuples::bigint AS approximate_count
FROM pg_class WHERE relname = 'orders';

-- Exact count with early termination check
SELECT count(*) FROM orders WHERE status = 'pending' LIMIT 1000;
-- If you only need to know "are there > 1000 pending?"
SELECT EXISTS(SELECT 1 FROM orders WHERE status = 'pending' LIMIT 1);
```

---

## Case Study 4: Pagination Performance

### Problem with OFFSET
```sql
-- SLOW at large offsets: database scans and discards 100,000 rows
SELECT * FROM orders ORDER BY id LIMIT 10 OFFSET 100000;
-- Execution: full scan of 100,010 rows, return last 10
```

### Fix: Keyset / Cursor Pagination
```sql
-- FAST: uses index on id, skips directly to last_seen_id
SELECT * FROM orders
WHERE id > :last_seen_id
ORDER BY id
LIMIT 10;

-- For multi-column sort (tie-breaking)
SELECT * FROM orders
WHERE (created_at, id) > (:last_ts, :last_id)
ORDER BY created_at, id
LIMIT 10;
```

**Requirements for keyset pagination**:
- Index on the sort column(s)
- Client tracks the last seen value(s)
- Cannot jump to arbitrary pages (sequential only)

### When OFFSET Is Acceptable
- First ~10 pages of a result set (OFFSET < 1000)
- Admin interfaces where users rarely go deep
- When random page access is required (no keyset alternative)

### Implementation Pattern
```sql
-- Create index supporting pagination
CREATE INDEX idx_orders_cursor ON orders (created_at DESC, id DESC);

-- Page query
SELECT id, total, created_at
FROM orders
WHERE (created_at, id) < (:cursor_ts, :cursor_id)  -- less than for DESC
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

---

## Query Plan Regression Detection

### Using pg_stat_statements
```sql
-- Enable in postgresql.conf
-- shared_preload_libraries = 'pg_stat_statements'

-- Top queries by total time (biggest optimization targets)
SELECT
  left(query, 80) AS query_snippet,
  calls,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round(stddev_exec_time::numeric, 2) AS stddev_ms,
  round(total_exec_time::numeric / 1000, 2) AS total_sec,
  rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Queries with high variance (inconsistent performance)
SELECT left(query, 80), calls, mean_exec_time, stddev_exec_time,
       stddev_exec_time / mean_exec_time AS cv  -- coefficient of variation
FROM pg_stat_statements
WHERE calls > 100
ORDER BY cv DESC
LIMIT 20;

-- Reset stats (do periodically to get recent picture)
SELECT pg_stat_statements_reset();
```

### Forcing Plan Comparison with pg_hint_plan
```sql
-- Test with index disabled
SET enable_indexscan = off;
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 123;
SET enable_indexscan = on;

-- Force specific join order
/*+ Leading(o u) HashJoin(o u) */
EXPLAIN ANALYZE
SELECT * FROM orders o JOIN users u ON u.id = o.user_id;
```

### auto_explain for Automatic Slow Query Capture
```conf
# postgresql.conf
shared_preload_libraries = 'auto_explain'
auto_explain.log_min_duration = 1000   # log plans for queries > 1s
auto_explain.log_analyze = on
auto_explain.log_buffers = on
```

---

## Cost Model Understanding

### Key Planner Cost Parameters
```conf
seq_page_cost = 1.0          # cost per sequential page read (reference)
random_page_cost = 4.0       # cost per random page read (default; lower for SSD)
cpu_tuple_cost = 0.01        # cost per row processed
cpu_index_tuple_cost = 0.005 # cost per index entry processed
cpu_operator_cost = 0.0025   # cost per operator evaluation
effective_cache_size = 4GB   # planner's estimate of available OS cache
```

**SSD tuning**: Lower `random_page_cost` to 1.1-2.0 for SSDs (random I/O nearly as fast as sequential).

```sql
-- Check current settings
SHOW random_page_cost;
SHOW effective_cache_size;

-- Tune for SSD
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_cache_size = '12GB';  -- ~75% of RAM
SELECT pg_reload_conf();
```

### Why Planner Chooses Wrong Plan
1. **Stale statistics**: `n_distinct` underestimated → row estimates off → run `ANALYZE`
2. **effective_cache_size too low**: planner thinks less data is cached → prefers Seq Scan
3. **random_page_cost too high**: planner avoids index scans → lower for SSD
4. **Correlated columns**: planner doesn't account for correlation between WHERE conditions → use extended statistics

```sql
-- Extended statistics for correlated columns
CREATE STATISTICS orders_status_region ON status, region FROM orders;
ANALYZE orders;
```
