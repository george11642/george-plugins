# Database Monitoring and Observability

## Key Metrics to Monitor

### Connection Health
```sql
-- Current connection count vs limit
SELECT count(*) AS total,
       max_conn,
       count(*) * 100 / max_conn AS pct_used
FROM pg_stat_activity,
     (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') s
GROUP BY max_conn;

-- By state
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state;
-- idle_in_transaction > a few → connection leak or long transactions
```

**Alert thresholds**:
- Connection count > 80% of `max_connections` → scale PgBouncer or add read replicas
- `idle in transaction` count > 5 → investigate connection leaks

### Cache Hit Ratio
```sql
-- Table cache hit ratio (target: > 99%)
SELECT
  relname,
  heap_blks_hit,
  heap_blks_read,
  round(heap_blks_hit::numeric / nullif(heap_blks_hit + heap_blks_read, 0) * 100, 2) AS cache_hit_pct
FROM pg_statio_user_tables
ORDER BY heap_blks_read DESC
LIMIT 20;

-- Index cache hit ratio (target: > 99%)
SELECT
  relname, indexrelname,
  idx_blks_hit, idx_blks_read,
  round(idx_blks_hit::numeric / nullif(idx_blks_hit + idx_blks_read, 0) * 100, 2) AS idx_cache_hit_pct
FROM pg_statio_user_indexes
ORDER BY idx_blks_read DESC
LIMIT 20;

-- Overall database cache hit
SELECT
  sum(blks_hit) AS cache_hits,
  sum(blks_read) AS disk_reads,
  round(sum(blks_hit)::numeric / nullif(sum(blks_hit) + sum(blks_read), 0) * 100, 2) AS cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();
```

**Below 99%**: increase `shared_buffers` (typically 25% of RAM) or add RAM.

### Dead Tuple Ratio
```sql
SELECT
  relname,
  n_live_tup,
  n_dead_tup,
  round(n_dead_tup::numeric / nullif(n_live_tup + n_dead_tup, 0) * 100, 1) AS dead_pct,
  last_autovacuum,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_pct DESC;
-- dead_pct > 5% → vacuum needed or autovacuum not keeping up
```

### Replication Lag
```sql
-- On primary: lag per standby
SELECT
  application_name,
  write_lag,
  flush_lag,
  replay_lag,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS byte_lag
FROM pg_stat_replication;

-- On standby: self-reported lag
SELECT now() - pg_last_xact_replay_timestamp() AS replication_delay;
```

**Alert thresholds**:
- Replay lag > 30s → investigate; > 5min → critical
- Byte lag > 1GB → risk of slot-induced WAL buildup on primary

### Long-Running Queries
```sql
SELECT
  pid, usename, state,
  now() - query_start AS duration,
  left(query, 100) AS query_snippet
FROM pg_stat_activity
WHERE state != 'idle'
  AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;
```

---

## pg_stat_statements Setup and Usage

### Enable
```conf
# postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 10000         # number of distinct statements to track
pg_stat_statements.track = all         # top, all, or none
pg_stat_statements.track_utility = on  # track COPY, CREATE TABLE, etc.
```

```sql
-- Create extension (once per database)
CREATE EXTENSION pg_stat_statements;
```

### Key Queries

```sql
-- Top 20 queries by total execution time (biggest optimization targets)
SELECT
  left(query, 100) AS query,
  calls,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round(stddev_exec_time::numeric, 2) AS stddev_ms,
  round(total_exec_time::numeric / 1000, 1) AS total_sec,
  rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Slowest individual queries (by mean execution time)
SELECT
  left(query, 100) AS query,
  calls,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round(max_exec_time::numeric, 2) AS max_ms
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Most called queries (high frequency = high impact)
SELECT
  left(query, 100) AS query,
  calls,
  round(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 20;

-- High I/O queries (shared_blks_read = cache misses)
SELECT
  left(query, 100) AS query,
  calls,
  shared_blks_read,
  shared_blks_hit,
  round(shared_blks_read::numeric / nullif(calls, 0), 0) AS avg_blks_read_per_call
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT 20;

-- Reset stats
SELECT pg_stat_statements_reset();
```

---

## Slow Query Log

```conf
# postgresql.conf
log_min_duration_statement = 1000    # log queries taking > 1000ms (1s)
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_lock_waits = on
log_temp_files = 0                   # log all temp file creation
```

### pgBadger for Log Analysis
```bash
# Install and analyze PostgreSQL logs
pgbadger /var/log/postgresql/postgresql-*.log -o report.html
# Generates: top slow queries, most frequent queries, lock wait analysis, connection count graphs
```

---

## Prometheus + Grafana Monitoring

### postgres_exporter Configuration
```yaml
# docker-compose.yml
postgres_exporter:
  image: prometheuscommunity/postgres-exporter
  environment:
    DATA_SOURCE_NAME: "postgresql://monitoring:password@postgres:5432/mydb?sslmode=disable"
  ports:
    - "9187:9187"
```

### Key Prometheus Metrics
```promql
# Cache hit ratio
rate(pg_stat_database_blks_hit[5m]) /
  (rate(pg_stat_database_blks_hit[5m]) + rate(pg_stat_database_blks_read[5m]))

# Connections used
pg_stat_activity_count / pg_settings_max_connections

# Replication lag (seconds)
pg_replication_lag

# Transaction rate
rate(pg_stat_database_xact_commit[5m]) + rate(pg_stat_database_xact_rollback[5m])

# Dead tuple ratio
pg_stat_user_tables_n_dead_tup / (pg_stat_user_tables_n_live_tup + pg_stat_user_tables_n_dead_tup)
```

### Alerting Rules (Prometheus)
```yaml
groups:
  - name: postgresql
    rules:
      - alert: HighConnectionUsage
        expr: pg_stat_activity_count / pg_settings_max_connections > 0.8
        for: 5m
        annotations:
          summary: "PostgreSQL connections above 80%"

      - alert: LowCacheHitRatio
        expr: |
          rate(pg_stat_database_blks_hit[5m]) /
          (rate(pg_stat_database_blks_hit[5m]) + rate(pg_stat_database_blks_read[5m])) < 0.95
        for: 10m
        annotations:
          summary: "Cache hit ratio below 95%"

      - alert: ReplicationLagHigh
        expr: pg_replication_lag > 30
        for: 2m
        annotations:
          summary: "Replication lag > 30 seconds"

      - alert: HighDeadTuples
        expr: pg_stat_user_tables_n_dead_tup > 100000
        for: 30m
        annotations:
          summary: "High dead tuple count — autovacuum may be lagging"
```

### Grafana Dashboard
- Use community dashboard ID **9628** (PostgreSQL Database) or **12485** (PostgreSQL Exporter)
- Import via Grafana UI: Dashboards → Import → Enter ID

---

## Capacity Planning

### Storage Growth Monitoring
```sql
-- Database size and growth
SELECT
  datname,
  pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- Table sizes with bloat estimate
SELECT
  schemaname, tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
```

### When to Scale

| Signal | Action |
|--------|--------|
| CPU > 70% sustained | Vertical scale (more CPU) or read replicas |
| RAM < 20% free | Add RAM (increase `shared_buffers`) |
| Cache hit < 95% | Add RAM |
| Connections > 80% | Add PgBouncer instances |
| Read IOPS saturated | Add read replicas |
| Storage > 70% full | Add storage (plan for index/WAL growth) |
| Write throughput saturated | Sharding or partitioning |

### WAL and Checkpoint Monitoring
```sql
-- Check checkpoint frequency
SELECT checkpoints_timed, checkpoints_req,
       checkpoint_write_time, checkpoint_sync_time
FROM pg_stat_bgwriter;
-- checkpoints_req >> checkpoints_timed → increase max_wal_size

-- WAL generation rate
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS total_wal_generated;
```

---

## EXPLAIN Plan Visualization Tools

### explain.depesz.com
- Paste `EXPLAIN ANALYZE` output → visual breakdown
- Color-coded by slowest nodes
- URL: https://explain.depesz.com

### pganalyze
- Automated explain plan capture for slow queries
- Continuous index advisor
- Historical plan comparison (detects regressions)
- Cloud-hosted or self-hosted

### auto_explain Module
```conf
# postgresql.conf — automatic explain for slow queries
shared_preload_libraries = 'auto_explain'
auto_explain.log_min_duration = 2000   # capture plans for queries > 2s
auto_explain.log_analyze = on
auto_explain.log_buffers = on
auto_explain.log_format = json         # machine-parseable
auto_explain.log_nested_statements = on
```

Plans appear in PostgreSQL log and can be forwarded to log aggregator (Loki, Splunk, CloudWatch).
