# PostgreSQL Reference

## Essential Extensions

Install extensions before using them. Check availability with `SELECT * FROM pg_available_extensions;`.

```sql
-- Must-have extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- Query performance tracking
CREATE EXTENSION IF NOT EXISTS pgcrypto;             -- gen_random_uuid(), encryption
CREATE EXTENSION IF NOT EXISTS pg_trgm;              -- Trigram similarity search
CREATE EXTENSION IF NOT EXISTS btree_gin;            -- GIN indexes on scalar types
CREATE EXTENSION IF NOT EXISTS uuid-ossp;            -- UUID generation (prefer pgcrypto)
```

## JSONB

Use JSONB (not JSON) for all JSON storage. JSONB is binary, indexable, and supports operators.

### Storage and Querying
```sql
CREATE TABLE events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  data JSONB NOT NULL DEFAULT '{}'
);

-- Extract values
SELECT data->>'name' AS name,                    -- text extraction
       data->'address'->>'city' AS city,          -- nested extraction
       (data->>'age')::int AS age                 -- cast to type
FROM events;

-- Filter on nested values
SELECT * FROM events WHERE data @> '{"type": "purchase"}';     -- containment
SELECT * FROM events WHERE data->>'status' = 'active';         -- path extraction
SELECT * FROM events WHERE data ? 'email';                      -- key exists
SELECT * FROM events WHERE data ?| ARRAY['email', 'phone'];    -- any key exists
```

### JSONB Indexes
```sql
-- GIN index: supports @>, ?, ?|, ?& operators
CREATE INDEX idx_events_data ON events USING GIN (data);

-- GIN with jsonb_path_ops: smaller, faster, only supports @>
CREATE INDEX idx_events_data_path ON events USING GIN (data jsonb_path_ops);

-- B-tree on extracted value: best for equality/range on specific keys
CREATE INDEX idx_events_status ON events ((data->>'status'));
CREATE INDEX idx_events_created ON events (((data->>'created_at')::timestamptz));
```

### JSONB Modification
```sql
-- Set a key
UPDATE events SET data = jsonb_set(data, '{status}', '"processed"');

-- Set nested key (creates path if missing)
UPDATE events SET data = jsonb_set(data, '{address,zip}', '"90210"', true);

-- Remove a key
UPDATE events SET data = data - 'temporary_field';

-- Merge objects
UPDATE events SET data = data || '{"processed": true, "version": 2}';
```

## Full-Text Search

Use tsvector/tsquery for full-text search. Faster and more featureful than LIKE/ILIKE.

```sql
-- Add search column
ALTER TABLE articles ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(body, '')), 'B')
  ) STORED;

CREATE INDEX idx_articles_search ON articles USING GIN (search_vector);

-- Search with ranking
SELECT title, ts_rank(search_vector, query) AS rank
FROM articles, plainto_tsquery('english', 'database optimization') AS query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 20;

-- Phrase search
SELECT * FROM articles
WHERE search_vector @@ phraseto_tsquery('english', 'connection pooling');

-- Highlight matches
SELECT ts_headline('english', body, plainto_tsquery('database'), 'StartSel=<b>, StopSel=</b>')
FROM articles
WHERE search_vector @@ plainto_tsquery('database');
```

## Table Partitioning

Partition large tables (100M+ rows) for query performance and maintenance. PostgreSQL 10+ supports declarative partitioning.

### Range Partitioning (most common — time-series data)
```sql
CREATE TABLE logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  created_at TIMESTAMPTZ NOT NULL,
  message TEXT,
  level TEXT
) PARTITION BY RANGE (created_at);

-- Create partitions (automate this with pg_partman)
CREATE TABLE logs_2025_01 PARTITION OF logs
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE logs_2025_02 PARTITION OF logs
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Default partition catches unmatched rows
CREATE TABLE logs_default PARTITION OF logs DEFAULT;
```

### List Partitioning (multi-tenant, region-based)
```sql
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  region TEXT NOT NULL,
  total NUMERIC
) PARTITION BY LIST (region);

CREATE TABLE orders_us PARTITION OF orders FOR VALUES IN ('us-east', 'us-west');
CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('eu-west', 'eu-central');
```

### Partition Maintenance
```sql
-- Detach old partition (non-blocking in PG 14+)
ALTER TABLE logs DETACH PARTITION logs_2024_01 CONCURRENTLY;

-- Drop or archive
DROP TABLE logs_2024_01;
```

## pgvector — Vector Similarity Search

Use pgvector for AI/ML embedding storage and similarity search.

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  content TEXT NOT NULL,
  embedding vector(1536)  -- OpenAI ada-002 dimension
);

-- IVFFlat index: faster build, good for < 1M vectors
CREATE INDEX idx_docs_embedding ON documents
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- HNSW index: better recall, slower build, good for all scales
CREATE INDEX idx_docs_embedding_hnsw ON documents
  USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- Similarity search (cosine distance)
SELECT id, content, embedding <=> '[0.1, 0.2, ...]'::vector AS distance
FROM documents
ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
LIMIT 10;

-- Set probes for IVFFlat (higher = better recall, slower)
SET ivfflat.probes = 10;

-- Filter + vector search (use partial index for best perf)
SELECT * FROM documents
WHERE category = 'technical'
ORDER BY embedding <=> $1
LIMIT 10;
```

## Performance Tuning

### Critical postgresql.conf Settings
```ini
# Memory (set based on available RAM)
shared_buffers = '4GB'              # 25% of RAM
effective_cache_size = '12GB'       # 75% of RAM
work_mem = '256MB'                  # per-sort/hash operation, be conservative
maintenance_work_mem = '1GB'        # for VACUUM, CREATE INDEX

# WAL
wal_buffers = '64MB'
checkpoint_completion_target = 0.9
max_wal_size = '4GB'

# Planner
random_page_cost = 1.1              # SSD (default 4.0 is for spinning disk)
effective_io_concurrency = 200      # SSD
default_statistics_target = 500     # more accurate plans

# Connections
max_connections = 200               # use PgBouncer, not high max_connections
```

### VACUUM and Autovacuum
Autovacuum reclaims dead tuples. Tune for write-heavy tables.

```sql
-- Check dead tuples
SELECT relname, n_dead_tup, n_live_tup, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Aggressive autovacuum for hot tables
ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.01,    -- trigger at 1% dead tuples (default 20%)
  autovacuum_analyze_scale_factor = 0.005,
  autovacuum_vacuum_cost_delay = 0          -- no throttling
);

-- Manual vacuum with progress monitoring
VACUUM (VERBOSE, ANALYZE) orders;
```

### Connection Pooling with PgBouncer
Configure PgBouncer in transaction mode for web applications:
```ini
[databases]
myapp = host=localhost port=5432 dbname=myapp

[pgbouncer]
pool_mode = transaction        # release connection after each transaction
max_client_conn = 1000         # accept many app connections
default_pool_size = 25         # actual PG connections per database
reserve_pool_size = 5
reserve_pool_timeout = 3
```

## Advisory Locks
Use advisory locks for application-level mutual exclusion without table locks.

```sql
-- Session-level lock (held until released or session ends)
SELECT pg_advisory_lock(12345);
-- ... do exclusive work ...
SELECT pg_advisory_unlock(12345);

-- Transaction-level lock (auto-released at COMMIT/ROLLBACK)
SELECT pg_advisory_xact_lock(hashtext('process-invoices'));

-- Non-blocking try
SELECT pg_try_advisory_lock(12345);  -- returns true/false
```

## Row-Level Security (RLS)
Enforce multi-tenant data isolation at the database level.

```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON documents
  USING (tenant_id = current_setting('app.tenant_id')::int);

-- Set tenant context per request
SET app.tenant_id = '42';
SELECT * FROM documents;  -- only sees tenant 42's data
```
