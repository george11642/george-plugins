# SQL Optimization Reference

## EXPLAIN Analysis

Always run EXPLAIN (ANALYZE, BUFFERS) on queries before deploying. Read the output bottom-up — the deepest nodes execute first.

### PostgreSQL EXPLAIN
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
```

Key metrics to watch:
- **actual time**: First row vs total time. Large gap = startup cost (sorts, hashes).
- **rows**: Compare estimated vs actual. Off by 10x+ means stale statistics — run `ANALYZE table_name`.
- **Buffers shared hit/read**: Hit = cache, read = disk. High read count = cold cache or missing index.
- **loops**: Nested loop iterations. 1000+ loops on a subplan = likely N+1 at the query level.

### MySQL EXPLAIN
```sql
EXPLAIN FORMAT=JSON SELECT ...;
```
Watch for `type: ALL` (full scan), `rows` estimate, `Extra: Using filesort` or `Using temporary`.

## Index Strategies

### Composite Index Column Order
Place columns in this order:
1. **Equality conditions first** (`WHERE status = 'active'`)
2. **Range conditions next** (`WHERE created_at > '2025-01-01'`)
3. **Sort columns last** (`ORDER BY name`)

```sql
-- Query: WHERE status = 'active' AND created_at > '2025-01-01' ORDER BY name
CREATE INDEX idx_orders_status_created_name ON orders (status, created_at, name);
```

The range condition "breaks" the index — columns after a range condition cannot be used for further filtering or sorting efficiently.

### Partial Indexes
Index only the rows that matter. Reduce index size and write overhead.

```sql
-- Only index active users (90% of queries filter on active)
CREATE INDEX idx_users_active_email ON users (email) WHERE deleted_at IS NULL;

-- Only index unprocessed jobs
CREATE INDEX idx_jobs_pending ON jobs (created_at) WHERE status = 'pending';
```

### Covering Indexes (Index-Only Scans)
Include all columns the query needs so the DB never touches the heap.

```sql
-- Query: SELECT email, name FROM users WHERE status = 'active'
CREATE INDEX idx_users_status_covering ON users (status) INCLUDE (email, name);
```

### Expression Indexes
Index computed values for queries that filter on expressions.

```sql
CREATE INDEX idx_users_lower_email ON users (LOWER(email));
-- Now this query uses the index:
SELECT * FROM users WHERE LOWER(email) = 'foo@bar.com';
```

### When NOT to Index
- Tables with fewer than ~1000 rows (seq scan is faster).
- Columns with very low cardinality (boolean flags) unless combined in a composite index.
- Write-heavy tables where index maintenance cost exceeds read benefit.

## Query Patterns

### Pagination
Avoid OFFSET for large datasets — it scans and discards rows.

```sql
-- BAD: OFFSET scans 10000 rows then discards them
SELECT * FROM posts ORDER BY id LIMIT 20 OFFSET 10000;

-- GOOD: Cursor-based pagination (keyset)
SELECT * FROM posts WHERE id > 10000 ORDER BY id LIMIT 20;

-- For non-unique sort columns, use a composite cursor
SELECT * FROM posts
WHERE (created_at, id) > ('2025-01-01', 500)
ORDER BY created_at, id
LIMIT 20;
```

### Batch Operations
Never UPDATE/DELETE millions of rows in one transaction. Batch to avoid lock contention and WAL bloat.

```sql
-- Batch delete in chunks of 1000
DO $$
DECLARE
  rows_deleted INT;
BEGIN
  LOOP
    DELETE FROM logs WHERE id IN (
      SELECT id FROM logs WHERE created_at < '2024-01-01' LIMIT 1000
    );
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    EXIT WHEN rows_deleted = 0;
    COMMIT;
  END LOOP;
END $$;
```

### Avoiding N+1
```sql
-- BAD: Fetch users, then loop to fetch orders for each
SELECT * FROM users WHERE active = true;
-- then for each user: SELECT * FROM orders WHERE user_id = ?;

-- GOOD: Single query with JOIN
SELECT u.*, o.id AS order_id, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.active = true;

-- GOOD: Subquery with IN (when you need separate result sets)
SELECT * FROM orders WHERE user_id IN (SELECT id FROM users WHERE active = true);
```

### CTEs (Common Table Expressions)
Use CTEs for readability. In PostgreSQL 12+, the planner can inline non-recursive CTEs (optimization fence removed).

```sql
WITH recent_orders AS (
  SELECT user_id, COUNT(*) AS order_count, SUM(total) AS total_spent
  FROM orders
  WHERE created_at > NOW() - INTERVAL '30 days'
  GROUP BY user_id
),
high_value AS (
  SELECT user_id FROM recent_orders WHERE total_spent > 1000
)
SELECT u.name, r.order_count, r.total_spent
FROM users u
JOIN recent_orders r ON r.user_id = u.id
WHERE u.id IN (SELECT user_id FROM high_value);
```

Force materialization when the CTE is referenced multiple times:
```sql
WITH expensive_calc AS MATERIALIZED (
  SELECT ... -- computed once, stored in temp
)
SELECT * FROM expensive_calc WHERE ...
UNION ALL
SELECT * FROM expensive_calc WHERE ...;
```

### Window Functions
Use window functions instead of self-joins or correlated subqueries.

```sql
-- Rank users by spending within each region
SELECT name, region, total_spent,
  RANK() OVER (PARTITION BY region ORDER BY total_spent DESC) AS rank
FROM users;

-- Running average over last 7 rows
SELECT date, revenue,
  AVG(revenue) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg
FROM daily_stats;

-- Detect gaps in sequences
SELECT id,
  LEAD(id) OVER (ORDER BY id) - id AS gap
FROM invoices
HAVING gap > 1;

-- Deduplicate: keep latest row per group
DELETE FROM events WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, event_type ORDER BY created_at DESC) AS rn
    FROM events
  ) t WHERE rn > 1
);
```

## Aggregation Optimization

### Pre-aggregate in Materialized Views
For dashboards and reporting queries that scan millions of rows:

```sql
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT DATE(created_at) AS day, product_id, SUM(amount) AS revenue, COUNT(*) AS order_count
FROM orders
GROUP BY DATE(created_at), product_id;

CREATE UNIQUE INDEX idx_daily_revenue ON daily_revenue (day, product_id);

-- Refresh periodically (concurrent avoids locking reads)
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue;
```

### Use FILTER Instead of CASE in Aggregates
```sql
-- Cleaner than SUM(CASE WHEN status = 'paid' THEN amount END)
SELECT
  COUNT(*) FILTER (WHERE status = 'paid') AS paid_count,
  SUM(amount) FILTER (WHERE status = 'paid') AS paid_total,
  COUNT(*) FILTER (WHERE status = 'refunded') AS refund_count
FROM orders;
```

## Statistics and Maintenance

### Keep Statistics Fresh
```sql
-- Update statistics for a specific table
ANALYZE orders;

-- Increase statistics target for high-cardinality columns
ALTER TABLE orders ALTER COLUMN user_id SET STATISTICS 1000;
```

### Monitor Slow Queries
```sql
-- PostgreSQL: enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slowest queries by total time
SELECT query, calls, total_exec_time, mean_exec_time, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### Lock Monitoring
```sql
-- Find blocking queries
SELECT blocked.pid AS blocked_pid, blocked.query AS blocked_query,
       blocking.pid AS blocking_pid, blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid
JOIN pg_locks kl ON kl.locktype = bl.locktype AND kl.relation = bl.relation AND kl.pid != bl.pid
JOIN pg_stat_activity blocking ON blocking.pid = kl.pid
WHERE NOT bl.granted;
```
