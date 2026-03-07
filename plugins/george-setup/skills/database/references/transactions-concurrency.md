# Transactions and Concurrency Control

## Isolation Levels in PostgreSQL

PostgreSQL implements four isolation levels (SQL standard), but READ UNCOMMITTED behaves identically to READ COMMITTED.

### READ COMMITTED (Default)
- Each statement sees data committed before **that statement** began
- Different statements in the same transaction may see different snapshots
- **Anomalies possible**: non-repeatable reads, phantom reads
- Best for: most OLTP workloads; minimal overhead

```sql
BEGIN; -- isolation level: READ COMMITTED (default)
SELECT balance FROM accounts WHERE id = 1;  -- sees $100
-- Another transaction commits: balance → $50
SELECT balance FROM accounts WHERE id = 1;  -- now sees $50 (non-repeatable read)
COMMIT;
```

### REPEATABLE READ
- Transaction sees data as of the **start of the transaction** (consistent snapshot)
- **Prevents**: dirty reads, non-repeatable reads
- **Still possible in standard SQL**: phantom reads — but PostgreSQL's MVCC prevents phantoms too
- Can fail with serialization error (40001) on concurrent UPDATE to same row

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 1;  -- sees $100
-- Another transaction commits: balance → $50
SELECT balance FROM accounts WHERE id = 1;  -- still sees $100 (repeatable)
COMMIT;
```

### SERIALIZABLE
- Full serializable isolation via SSI (Serializable Snapshot Isolation)
- Transactions appear to execute in some serial order
- May abort with serialization failure (40001) — application must retry
- Performance overhead: ~10-15% compared to READ COMMITTED
- Use for: financial transfers, inventory management, any operation requiring strict consistency

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- ... reads and writes ...
COMMIT;  -- may fail with: ERROR: could not serialize access due to read/write dependencies
```

### READ UNCOMMITTED
- PostgreSQL treats this identically to READ COMMITTED (dirty reads not possible due to MVCC)
- Only exists for SQL standard compatibility

---

## Anomalies by Isolation Level

| Anomaly | READ COMMITTED | REPEATABLE READ | SERIALIZABLE |
|---------|---------------|-----------------|--------------|
| Dirty read | No (MVCC) | No | No |
| Non-repeatable read | Yes | No | No |
| Phantom read | Yes | No (PG) | No |
| Write skew | Yes | Yes | No |
| Lost update | Yes (without FOR UPDATE) | No | No |

### Write Skew (the tricky one)
```sql
-- Two doctors, both check "at least 1 on call", both see the other, both go off call
-- Tx1: SELECT count(*) FROM oncall WHERE shift = 'night'; -- sees 2
-- Tx2: SELECT count(*) FROM oncall WHERE shift = 'night'; -- sees 2
-- Tx1: UPDATE oncall SET status='off' WHERE doctor_id=1; -- now 1 on call
-- Tx2: UPDATE oncall SET status='off' WHERE doctor_id=2; -- now 0 on call!
-- Both committed. Invariant violated. Only SERIALIZABLE prevents this.
```

---

## MVCC (Multi-Version Concurrency Control)

### How It Works
Every row has two hidden system columns:
- `xmin`: transaction ID that inserted/created this row version
- `xmax`: transaction ID that deleted/updated this row version (0 = alive)

```sql
-- See MVCC internals (requires superuser or table access)
SELECT xmin, xmax, id, name FROM users WHERE id = 1;
```

### Snapshot Isolation
When a transaction starts, PostgreSQL takes a snapshot:
- `xmin`: lowest active transaction ID (all older transactions are visible)
- `xip_list`: list of in-progress transaction IDs (these rows are NOT visible)
- A row is visible if `xmin` committed before snapshot AND (`xmax` = 0 OR `xmax` not yet committed)

### Dead Tuples
When a row is updated or deleted, the old version is marked dead (`xmax` set) but not immediately removed.

```sql
-- Check dead tuple accumulation
SELECT relname, n_live_tup, n_dead_tup,
       round(n_dead_tup::numeric / nullif(n_live_tup + n_dead_tup, 0) * 100, 1) AS dead_pct,
       last_vacuum, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
-- dead_pct > 5-10% → trigger manual VACUUM
```

### Long Transactions and Bloat
Long-running transactions prevent VACUUM from reclaiming dead tuples (VACUUM cannot remove rows visible to any active transaction).

```sql
-- Find long-running transactions (dangerous for bloat)
SELECT pid, usename, state, xact_start,
       now() - xact_start AS duration,
       left(query, 80) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND now() - xact_start > interval '5 minutes'
ORDER BY duration DESC;

-- Kill if necessary
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE now() - xact_start > interval '30 minutes';
```

### VACUUM and autovacuum
```sql
-- Manual vacuum (reclaims dead tuples)
VACUUM ANALYZE orders;

-- Aggressive vacuum (also reclaims space for reuse by OS)
VACUUM FULL orders;  -- WARNING: takes exclusive lock, rewrites table

-- Tune autovacuum for high-write tables
ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.01,   -- vacuum when 1% dead (not 20%)
  autovacuum_analyze_scale_factor = 0.005  -- analyze when 0.5% changed
);
```

---

## Deadlock Detection

### How PostgreSQL Handles Deadlocks
- Automatically detects deadlock cycles (every `deadlock_timeout`, default 1s)
- Kills one transaction (the lighter one by estimated cost) with:
  `ERROR: deadlock detected DETAIL: Process N waits for ShareLock on transaction M`
- Other transaction continues normally

### Deadlock Avoidance: Consistent Lock Ordering
```sql
-- BAD: Tx1 locks user 1 then user 2; Tx2 locks user 2 then user 1
-- → deadlock possible

-- GOOD: Always lock in ascending ID order
BEGIN;
SELECT * FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
-- Both transactions lock in same order → no deadlock
```

### lock_timeout for Fast Failure
```sql
-- Fail fast instead of waiting for lock
SET lock_timeout = '5s';
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
-- If lock not available in 5s: ERROR: canceling statement due to lock timeout
```

---

## Locking Patterns

### SELECT FOR UPDATE (Pessimistic Row Lock)
```sql
-- Lock rows for update — blocks other FOR UPDATE on same rows
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

### SELECT FOR SHARE (Shared Read Lock)
```sql
-- Multiple transactions can hold FOR SHARE simultaneously
-- Blocks FOR UPDATE (prevents modification while you hold share lock)
BEGIN;
SELECT * FROM users WHERE id = 1 FOR SHARE;
-- Safe to read, no one can modify while you hold this
COMMIT;
```

### SKIP LOCKED (Queue Processing Pattern)
```sql
-- Efficient job queue: skip rows locked by other workers
BEGIN;
SELECT id, payload
FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
-- Process job...
UPDATE jobs SET status = 'done' WHERE id = :id;
COMMIT;
-- No waiting, no deadlocks — each worker gets its own row
```

### Advisory Locks (Application-Level Mutex)
```sql
-- Try to acquire lock (non-blocking)
SELECT pg_try_advisory_lock(12345);  -- returns true/false
-- If true: you have the lock, do work
-- Release when done:
SELECT pg_advisory_unlock(12345);

-- Session-scoped: auto-released on disconnect
-- Transaction-scoped advisory lock:
SELECT pg_try_advisory_xact_lock(12345);  -- auto-released at transaction end

-- Use case: distributed cron job deduplication
BEGIN;
IF pg_try_advisory_xact_lock(hashtext('daily_report_job')) THEN
  -- run job
END IF;
COMMIT;
```

---

## Serialization Failure Handling

### Error Codes
- `40001`: serialization_failure (REPEATABLE READ or SERIALIZABLE conflict)
- `40P01`: deadlock_detected

### Retry Pattern
```python
import psycopg2
import time
import random

def run_with_retry(conn, fn, max_retries=3):
    for attempt in range(max_retries):
        try:
            with conn.cursor() as cur:
                fn(cur)
            conn.commit()
            return
        except psycopg2.errors.SerializationFailure:
            conn.rollback()
            if attempt == max_retries - 1:
                raise
            # Exponential backoff with jitter
            time.sleep((2 ** attempt) * 0.1 + random.uniform(0, 0.1))
        except psycopg2.errors.DeadlockDetected:
            conn.rollback()
            if attempt == max_retries - 1:
                raise
            time.sleep(random.uniform(0.05, 0.2))
```

### Idempotent Transaction Design
Transactions that may be retried must be idempotent:
```sql
-- Use upsert instead of insert to handle retries
INSERT INTO payments (id, amount, status)
VALUES (:id, :amount, 'pending')
ON CONFLICT (id) DO NOTHING;
-- If retried: ON CONFLICT prevents duplicate

-- Or check before insert
INSERT INTO payments (id, amount)
SELECT :id, :amount
WHERE NOT EXISTS (SELECT 1 FROM payments WHERE id = :id);
```

---

## Optimistic vs Pessimistic Locking

### Optimistic Locking (Version Column)
```sql
-- Schema: add version column
ALTER TABLE products ADD COLUMN version INTEGER DEFAULT 1;

-- Read
SELECT id, price, version FROM products WHERE id = 1;
-- Returns: id=1, price=100, version=5

-- Update (check version matches — fails if concurrent update happened)
UPDATE products
SET price = 110, version = version + 1
WHERE id = 1 AND version = 5;
-- If 0 rows affected → someone else updated → retry with fresh read
```

```python
rows_updated = db.execute(
    "UPDATE products SET price=?, version=version+1 WHERE id=? AND version=?",
    [new_price, product_id, current_version]
).rowcount

if rows_updated == 0:
    raise OptimisticLockError("Concurrent modification detected — please retry")
```

### Pessimistic Locking (FOR UPDATE)
```sql
BEGIN;
SELECT id, price FROM products WHERE id = 1 FOR UPDATE;
-- Row is locked — concurrent transactions block here
UPDATE products SET price = 110 WHERE id = 1;
COMMIT;
```

### When to Use Each

| Scenario | Use |
|----------|-----|
| Read-heavy, low contention | Optimistic (no DB lock held) |
| Write-heavy, high contention | Pessimistic (avoid retry storm) |
| Short critical sections | Pessimistic (predictable latency) |
| Long operations (user edits form) | Optimistic (can't hold DB lock for seconds) |
| Queue processing | SKIP LOCKED (specialized pessimistic) |
