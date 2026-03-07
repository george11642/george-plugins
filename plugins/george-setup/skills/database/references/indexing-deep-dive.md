# PostgreSQL Indexing Deep Dive

## Index Types in PostgreSQL

### B-tree (default)
- **Use cases**: equality (`=`), range (`<`, `>`, `BETWEEN`), `ORDER BY`, `LIKE 'prefix%'`, `IS NULL`
- Default when no `USING` clause specified
- Balanced tree: O(log n) lookups
- Supports all comparison operators
- Handles NULLs (stored at one end, controllable with `NULLS FIRST/LAST`)

```sql
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_orders_created ON orders (created_at DESC NULLS LAST);
```

### Hash
- **Use cases**: equality only (`=`), faster than B-tree for pure equality
- Does NOT support range queries, sorting, or composite indexes
- Not WAL-logged before PG 10 (unsafe for replication — fixed in PG 10+)
- Rarely worth it over B-tree; use only when profiling proves benefit

```sql
CREATE INDEX idx_sessions_token ON sessions USING HASH (token);
```

### GIN (Generalized Inverted Index)
- **Use cases**: JSONB (`@>`, `?`, `?|`, `?&`), arrays (`&&`, `<@`, `@>`), full-text search (`@@`)
- Stores per-element → row mapping (inverted)
- Slower to build/update than B-tree but powerful for containment queries
- `fastupdate` parameter: batch pending inserts (default on, can cause flush spikes)

```sql
-- JSONB containment
CREATE INDEX idx_products_tags ON products USING GIN (tags);

-- JSONB field extraction
CREATE INDEX idx_events_data ON events USING GIN ((data->'tags'));

-- Full-text search
CREATE INDEX idx_articles_fts ON articles USING GIN (to_tsvector('english', body));

-- Array containment
CREATE INDEX idx_posts_labels ON posts USING GIN (labels);
```

### GiST (Generalized Search Tree)
- **Use cases**: geometric types (point, box, polygon), range types (`tsrange`, `daterange`), full-text search (alternative to GIN), nearest-neighbor (`<->` operator)
- Lossy: may produce false positives, requires heap recheck
- Supports KNN queries (ORDER BY col <-> target LIMIT n)

```sql
-- Geometric proximity
CREATE INDEX idx_locations_point ON locations USING GIST (coords);

-- Range type overlap
CREATE INDEX idx_bookings_period ON bookings USING GIST (during);

-- KNN nearest-neighbor query
SELECT * FROM locations ORDER BY coords <-> '(40.7,-74.0)' LIMIT 10;
```

### BRIN (Block Range Index)
- **Use cases**: large tables with sequential/correlated data (timestamps, serial IDs, append-only logs)
- Stores min/max per block range (not per row) — extremely small footprint
- 1MB index for 100M rows vs B-tree's 3GB
- **Correlation requirement**: only effective when physical row order correlates with column value order
- `pages_per_range` parameter: default 128, smaller = more precise but larger index

```sql
CREATE INDEX idx_events_ts ON events USING BRIN (created_at);
CREATE INDEX idx_logs_id ON logs USING BRIN (id) WITH (pages_per_range = 64);
```

Check correlation before choosing BRIN:
```sql
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'events' AND attname = 'created_at';
-- correlation > 0.9 → BRIN is excellent
-- correlation < 0.5 → use B-tree instead
```

### SP-GiST (Space-Partitioned GiST)
- **Use cases**: non-balanced tree structures — IP ranges (`inet`), phone numbers, text with common prefixes, quadtrees
- More efficient than GiST for specific partitioned data
- Less commonly used; check if your extension requires it

```sql
CREATE INDEX idx_ips ON connections USING SPGIST (client_ip);
```

---

## Index Selectivity Analysis

### What Is Selectivity
Selectivity = fraction of rows matched by a predicate.
- High selectivity (0.01 = 1% of rows) → index pays off
- Low selectivity (0.5 = 50% of rows) → full scan is faster
- Rule of thumb: index not worth it if returning > 5-10% of table rows

### Using pg_stats
```sql
-- Check column statistics used by the planner
SELECT
  attname,
  n_distinct,        -- negative = fraction of table (e.g. -0.95 = 95% unique)
  correlation,       -- physical order correlation (-1 to 1)
  most_common_vals,  -- top N values
  most_common_freqs  -- frequency of top N values
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'status';
```

### Estimating Index Value
```sql
-- Estimated selectivity for a value
SELECT (SELECT count(*) FROM orders WHERE status = 'pending')::float
     / (SELECT count(*) FROM orders);
-- Result < 0.05 → index strongly recommended
-- Result > 0.15 → full scan likely faster
```

### Statistics Staleness
- Planner uses stale stats → bad row estimates → wrong plan
- Fix: `ANALYZE tablename;` or `VACUUM ANALYZE tablename;`
- Auto-analyze threshold: `autovacuum_analyze_scale_factor` (default 0.2 = 20% changes)
- For large tables: lower to 0.01-0.05

```sql
-- Check when table was last analyzed
SELECT relname, last_analyze, last_autoanalyze, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'orders';
```

---

## Composite Index Strategies

### Column Ordering Rule
**Equality columns first, range columns last.**

```sql
-- Query: WHERE status = 'active' AND created_at > '2024-01-01'
-- CORRECT: equality (status) first, range (created_at) last
CREATE INDEX idx_orders_status_created ON orders (status, created_at);

-- WRONG: range first wastes the index for the equality predicate
CREATE INDEX idx_orders_created_status ON orders (created_at, status); -- suboptimal
```

### Index Prefix Rule
A composite index on `(a, b, c)` can be used for queries on:
- `a` alone
- `a, b` together
- `a, b, c` together
- NOT: `b` alone, `c` alone, `b, c` together

### Covering Indexes (INCLUDE clause)
Avoid heap fetch entirely (index-only scan) by including extra columns:

```sql
-- Query: SELECT email, name FROM users WHERE user_id = ?
-- Without INCLUDE: index scan + heap fetch for name
-- With INCLUDE: index-only scan
CREATE INDEX idx_users_id_cover ON users (user_id) INCLUDE (email, name);
```

**When to use INCLUDE**:
- Column is in SELECT but not WHERE/ORDER BY
- Table is frequently read (INCLUDE adds storage, not search cost)
- `pg_stat_user_indexes`: check `idx_scan` → `idx_tup_fetch` ratio (low ratio = good index-only scan rate)

### When NOT to Add More Columns
- 4th+ column in composite index rarely helps (query must filter on first 3)
- Each extra column increases index size and write overhead
- Profile first: check `idx_scan` count before adding columns

---

## Advanced Index Patterns

### Expression / Functional Indexes
Index the result of a function, not the raw column:

```sql
-- Case-insensitive email lookup
CREATE INDEX idx_users_email_lower ON users (lower(email));
-- Query must use same expression:
SELECT * FROM users WHERE lower(email) = lower('User@Example.com');

-- Computed date part
CREATE INDEX idx_orders_year ON orders (EXTRACT(year FROM created_at));

-- COALESCE for nullable columns
CREATE INDEX idx_events_resolved ON events (COALESCE(resolved_at, '9999-12-31'));
```

### Partial Indexes (WHERE clause)
Index only a subset of rows — smaller, faster, more selective:

```sql
-- Soft-delete pattern: only index non-deleted rows
CREATE INDEX idx_users_active ON users (email) WHERE deleted_at IS NULL;

-- Only index recent/unprocessed items
CREATE INDEX idx_jobs_pending ON jobs (created_at) WHERE status = 'pending';

-- Only index non-null values
CREATE INDEX idx_orders_external ON orders (external_id) WHERE external_id IS NOT NULL;
```

**Requirement**: query WHERE clause must match (or imply) the partial index predicate.

### JSONB Index Patterns
```sql
-- GIN index on entire JSONB column (all keys searchable)
CREATE INDEX idx_events_data ON events USING GIN (data);

-- GIN index on specific nested key (more selective)
CREATE INDEX idx_events_tags ON events USING GIN ((data->'tags'));

-- B-tree on extracted scalar value
CREATE INDEX idx_events_user ON events ((data->>'user_id'));

-- Queries that use these indexes:
SELECT * FROM events WHERE data @> '{"user_id": "123"}';  -- GIN
SELECT * FROM events WHERE data->>'user_id' = '123';       -- B-tree on extraction
SELECT * FROM events WHERE data->'tags' ? 'urgent';        -- GIN on tags key
```

---

## Index Maintenance

### HOT Updates (Heap Only Tuple)
When an UPDATE only modifies columns not in any index, PostgreSQL uses HOT updates:
- No new index entry created — avoids index bloat
- Linked via heap pointer chain
- Implication: adding indexes on frequently-updated columns increases write overhead

```sql
-- Check HOT update rate
SELECT relname, n_tup_hot_upd, n_tup_upd,
       round(n_tup_hot_upd::numeric / nullif(n_tup_upd,0) * 100, 1) AS hot_pct
FROM pg_stat_user_tables
WHERE relname = 'orders';
-- Low hot_pct with many indexes → reconsider index set
```

### Detecting Unused Indexes
```sql
-- Indexes never scanned since last stats reset
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexname NOT LIKE '%pkey%'  -- keep primary keys
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Index Bloat Detection
```sql
-- Bloated indexes (estimated)
SELECT
  schemaname, tablename, indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  idx_scan
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;

-- Rebuild bloated index without locking
REINDEX INDEX CONCURRENTLY idx_orders_created;
```

### Fill Factor for Write-Heavy Tables
- Default fill factor: 90% for B-tree
- Lower fill factor (70-80%) leaves room for in-page updates → reduces splits → reduces bloat
- Trade-off: more pages = more storage, slightly slower range scans

```sql
-- Create index with lower fill factor for write-heavy table
CREATE INDEX idx_orders_status ON orders (status) WITH (fillfactor = 70);

-- Alter existing index fill factor (requires REINDEX to take effect)
ALTER INDEX idx_orders_status SET (fillfactor = 70);
REINDEX INDEX CONCURRENTLY idx_orders_status;
```

### BRIN vs B-tree Performance Comparison

| Metric | B-tree | BRIN |
|--------|--------|------|
| Index size (100M rows) | ~3 GB | ~1 MB |
| Build time | Minutes | Seconds |
| Lookup speed | O(log n) | O(pages/range) |
| Range query | Excellent | Good (if correlated) |
| Random access | Excellent | Poor |
| Best for | Any column | Sequential/correlated only |

**BRIN pages_per_range tuning**:
- Smaller `pages_per_range` → more precise, slightly larger index
- Default 128 pages per range covers ~1MB of data per range entry
- For very large tables or finer granularity: use 32 or 64

```sql
-- Tune BRIN range size
CREATE INDEX idx_metrics_ts ON metrics USING BRIN (recorded_at)
  WITH (pages_per_range = 32);
```

---

## Quick Index Decision Tree

```
Is query on equality only AND column has high cardinality?
  → Try Hash (rarely beats B-tree, test first)

Is data JSONB, array, or full-text?
  → GIN

Is data geometric, range type, or need KNN?
  → GiST

Is table large (>10M rows), append-only, with sequential timestamps/IDs?
  → BRIN (check correlation > 0.9 first)

Is data IP addresses or prefixed strings needing space partitioning?
  → SP-GiST

Everything else:
  → B-tree (default)
```
