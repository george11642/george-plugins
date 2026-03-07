# Connection Pooling and Operations

## Why Connection Pooling Is Mandatory

PostgreSQL uses a process-per-connection model — each connection forks a backend process.

**Connection costs**:
- ~5-10MB RAM per connection (backend process + stack + memory context)
- Fork overhead on connection establishment (~1-5ms)
- Typical safe limit: 100-300 connections before RAM pressure and context-switch overhead degrades performance
- Each idle connection still consumes memory

**Without pooling**: 500 app instances × 10 connections each = 5,000 PostgreSQL connections → OOM or degraded throughput.

**With pooling**: 5,000 app connections → PgBouncer → 50-100 actual PostgreSQL connections.

### max_connections Formula
```conf
# Starting point (not a hard rule)
max_connections = (cpu_cores × 2) + effective_disk_spindles
# Typical: 100-400 depending on RAM and workload
# For RDS/Cloud: set based on instance RAM (1GB RAM ≈ 100 connections)
```

---

## PgBouncer Modes

### Session Pooling
- 1 server connection per client session (held until client disconnects)
- Simplest — no restrictions on SQL features
- Use for: long-lived connections, clients using session state (SET, advisory locks, temp tables)
- Least efficient: doesn't help much with connection count reduction

### Transaction Pooling (Recommended for Web Apps)
- Server connection held only for duration of a transaction
- Released back to pool when transaction commits/rolls back
- **Restrictions**: no `SET` that persists across transactions, no `LISTEN/NOTIFY`, no advisory locks, no prepared statements (unless `server_reset_query` configured), no temp tables across transactions
- Best for: stateless web application backends

### Statement Pooling
- Server connection released after each statement
- Most aggressive pooling (most efficient)
- **Restrictions**: multi-statement transactions not allowed, no transactions spanning multiple statements
- Rarely used in practice — transaction pooling is usually sufficient

---

## PgBouncer Configuration

### `pgbouncer.ini` Structure
```ini
[databases]
myapp = host=postgres-primary port=5432 dbname=myapp
myapp_ro = host=postgres-replica port=5432 dbname=myapp

[pgbouncer]
# Mode
pool_mode = transaction

# Connection limits
max_client_conn = 10000        # total client connections PgBouncer accepts
default_pool_size = 25         # server connections per (db, user) pair
min_pool_size = 5              # keep this many open even when idle
reserve_pool_size = 5          # extra connections for clients waiting > reserve_pool_timeout
reserve_pool_timeout = 5       # seconds to wait before using reserve pool

# Connection lifecycle
server_lifetime = 3600         # close server connections older than 1hr
server_idle_timeout = 600      # close idle server connections after 10min
server_reset_query = DISCARD ALL  # run after each transaction (transaction mode)

# Authentication
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Logging
log_connections = 0
log_disconnections = 0
log_pooler_errors = 1

# Admin
listen_addr = 0.0.0.0
listen_port = 5432
admin_users = pgbouncer_admin
```

### Per-Database Pool Override
```ini
[databases]
# Override pool size for specific database
high_traffic_db = host=postgres port=5432 dbname=hightraffic pool_size=50
```

### Authentication Setup
```bash
# userlist.txt format: "username" "md5hash_or_password"
"appuser" "md5$(echo -n 'passwordappuser' | md5sum | cut -d' ' -f1)"
# Or with scram: use pg_shadow to extract
```

---

## Pool Sizing Formula

### Target Utilization Approach
```
target_connections = max_connections_to_postgres × 0.8  (80% utilization, 20% headroom)
pool_size = target_connections / num_pgbouncer_instances

Example:
- PostgreSQL max_connections = 200
- Leave 15 for admin/superuser = 185 usable
- 80% target = 148 connections
- 2 PgBouncer instances: pool_size = 74 each
```

### Reserve Pool
- `reserve_pool_size = 5-10` for admin tasks and unexpected bursts
- Ensure: `(pools × pool_size) + reserve_pool_size < max_connections - 15`

### Validate Pool Sizing
```sql
-- Connect to PgBouncer admin console
SHOW POOLS;
-- Check: sv_idle (idle server conns), sv_active (busy), cl_waiting (queued clients)
-- cl_waiting > 0 consistently → increase pool_size

SHOW STATS;
-- avg_query_time: time queries spend in PgBouncer + PostgreSQL
-- avg_wait_time: time clients wait for a connection from the pool
-- avg_wait_time > 5ms → pool exhaustion
```

---

## PgBouncer vs Alternatives

| Tool | Pros | Cons | Best For |
|------|------|------|----------|
| **PgBouncer** | Proven, lightweight, simple config, C performance | No load balancing, separate process | Most production use cases |
| **Pgpool-II** | Load balancing + pooling, query cache | Complex config, higher overhead | Multi-replica load balancing |
| **RDS Proxy** | Managed, IAM auth, serverless auto-scaling | AWS-only, cost per connection | AWS RDS/Aurora serverless |
| **Supabase Supavisor** | Elixir-based, cloud-native, multi-tenant | Newer, less battle-tested | Supabase or multi-tenant SaaS |

---

## Connection Leak Detection and Prevention

### Detecting Leaks
```sql
-- Find idle connections held too long
SELECT pid, usename, application_name, state, query_start,
       now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'idle'
  AND now() - query_start > interval '5 minutes';

-- Find idle-in-transaction (dangerous — holds locks)
SELECT pid, usename, state, now() - xact_start AS xact_duration, query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_duration DESC;

-- Kill a stuck connection
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - xact_start > interval '10 minutes';
```

### Prevention Settings
```conf
# postgresql.conf
idle_in_transaction_session_timeout = 30000   # kill idle-in-transaction after 30s
statement_timeout = 30000                      # kill statements running > 30s
tcp_keepalives_idle = 60                       # detect dead connections
```

### Application-Level Connection Management
```python
# SQLAlchemy: configure pool with leak detection
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
    pool_recycle=1800,      # recycle connections after 30min
    pool_pre_ping=True,     # test connection before use (detects dropped connections)
)
```

---

## Multi-Tenant Pooling

### Per-Tenant Connection Limits
```ini
# pgbouncer.ini: limit connections per tenant database
tenant_a_db = host=postgres dbname=tenant_a pool_size=10
tenant_b_db = host=postgres dbname=tenant_b pool_size=5
```

### Tenant Context via SET LOCAL
```sql
-- Set tenant context within transaction (compatible with transaction pooling)
BEGIN;
SET LOCAL app.current_tenant = '12345';
SELECT * FROM orders;  -- use RLS with current_setting('app.current_tenant')
COMMIT;
-- Connection returns to pool, SET LOCAL is cleared automatically
```

### Row Level Security with Pooling
```sql
-- RLS policy using session parameter
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.current_tenant')::bigint);

-- Application sets before each transaction
BEGIN;
SET LOCAL app.current_tenant = :tenant_id;
-- all queries filtered by RLS
COMMIT;
```
