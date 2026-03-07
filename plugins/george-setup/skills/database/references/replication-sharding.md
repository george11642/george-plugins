# PostgreSQL Replication and Sharding

## Streaming Replication (Physical)

Physical replication copies the WAL (Write-Ahead Log) byte-for-byte from primary to standby. The standby is an exact binary replica.

### Setup Overview

**Primary server** (`postgresql.conf`):
```conf
wal_level = replica          # minimum for streaming replication
max_wal_senders = 10         # max concurrent replication connections
wal_keep_size = 1GB          # WAL to retain (before replication slots)
synchronous_standby_names = '' # async by default
```

**Primary** (`pg_hba.conf`):
```conf
host  replication  replicator  10.0.1.0/24  scram-sha-256
```

**Create replication user**:
```sql
CREATE USER replicator REPLICATION LOGIN PASSWORD 'secret';
```

**Standby** (`postgresql.conf`):
```conf
primary_conninfo = 'host=primary port=5432 user=replicator password=secret'
hot_standby = on
```

**Bootstrap standby**:
```bash
pg_basebackup -h primary -U replicator -D /var/lib/postgresql/data -P -Xs -R
# -R creates standby.signal and primary_conninfo automatically
```

### Replication Slots
Prevent WAL removal until standby has consumed it — protects against standby falling behind:

```sql
-- Create slot on primary
SELECT pg_create_physical_replication_slot('standby1_slot');

-- Monitor slot lag (critical: large lag = primary disk fill)
SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag
FROM pg_replication_slots;

-- WARNING: unused slot with no limit will fill primary disk
-- Set max_slot_wal_keep_size to cap WAL retention
```

`postgresql.conf`:
```conf
max_slot_wal_keep_size = 10GB  # prevents disk fill from lagged standbys
```

### Synchronous vs Asynchronous

**Asynchronous** (default): primary commits immediately, standby may lag.
- Risk: data loss on primary crash (RPO > 0)
- Benefit: no latency impact

**Synchronous**: primary waits for standby acknowledgment before commit returns.
- Risk: write latency increases; if standby fails, primary blocks
- Benefit: zero RPO

```conf
# Require 1 synchronous standby
synchronous_standby_names = 'standby1'

# ANY 1 of 2 standbys (quorum)
synchronous_standby_names = 'ANY 1 (standby1, standby2)'
```

**FIRST vs ANY**:
- `FIRST n (list)`: first n in priority order must acknowledge
- `ANY n (list)`: any n from list (quorum — more flexible)

### Monitoring Replication Lag
```sql
-- On primary: view connected standbys and lag
SELECT
  application_name,
  state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;

-- On standby: check own lag
SELECT now() - pg_last_xact_replay_timestamp() AS replication_delay;
```

### Failover and Promotion
```sql
-- Manual promotion (on standby)
SELECT pg_promote();

-- Or via signal file (legacy)
-- touch /var/lib/postgresql/data/promote.trigger
```

### High Availability Tools

**pg_auto_failover**: Simple 2-node HA with automatic promotion.
- Monitor node tracks primary/standby state
- Automatic failover with fencing

**Patroni**: Enterprise-grade HA using distributed consensus (etcd, Consul, ZooKeeper).
- Leader election via consensus
- REST API for state management
- Works with HAProxy or load balancer for transparent failover
- Industry standard for production PostgreSQL clusters

**Architecture with Patroni**:
```
[App] → [HAProxy] → [Patroni Primary]
                  ↘ [Patroni Standby 1]
                  ↘ [Patroni Standby 2]
[etcd cluster: 3 nodes for consensus]
```

---

## Logical Replication

Logical replication replicates individual row changes (INSERT/UPDATE/DELETE) based on replication identity, not raw WAL bytes.

### Publication / Subscription Model

```sql
-- On publisher (source database)
CREATE PUBLICATION my_pub FOR TABLE orders, users;
-- Or all tables:
CREATE PUBLICATION my_pub FOR ALL TABLES;

-- On subscriber (destination database — table must exist with same schema)
CREATE SUBSCRIPTION my_sub
  CONNECTION 'host=publisher port=5432 dbname=mydb user=replicator password=secret'
  PUBLICATION my_pub;
```

### Row and Column Filtering (PG 15+)
```sql
-- Replicate only active users
CREATE PUBLICATION active_users FOR TABLE users WHERE (status = 'active');

-- Replicate only specific columns
CREATE PUBLICATION users_public FOR TABLE users (id, name, email);
```

### Use Cases
- **Table-level selective replication**: replicate subset of tables to analytics DB
- **Zero-downtime major version upgrade**: PG 14 → PG 16 with minimal cutover window
- **Multi-region read replicas**: with application-level routing
- **Data warehousing**: stream OLTP changes to OLAP system

### Limitations
- No DDL replication — schema changes must be applied manually to subscriber
- No sequence replication — sequences need manual sync or application-level handling
- No large object replication
- Subscriber must have tables pre-created

### Change Data Capture (CDC)

**pgoutput** (built-in, PG 10+):
- Native output plugin used by logical replication
- Used directly by `pg_logical` and replication slots

**wal2json**: Outputs WAL changes as JSON — useful for custom consumers.
```bash
# Read changes as JSON stream
pg_recvlogical -d mydb --slot my_slot --start -o pretty-print=1 -f -
```

**Debezium**: Production CDC platform — streams PostgreSQL changes to Kafka.
```json
// Debezium connector config
{
  "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
  "database.hostname": "postgres",
  "database.port": "5432",
  "database.user": "replicator",
  "database.dbname": "mydb",
  "plugin.name": "pgoutput",
  "slot.name": "debezium_slot",
  "topic.prefix": "myapp"
}
```

---

## Read Replicas

### Connection Routing Strategies

**Application-level routing** (simplest):
```python
# Read from replica, write to primary
read_db = connect(REPLICA_URL)
write_db = connect(PRIMARY_URL)
```

**PgBouncer with read/write split**:
- Two PgBouncer pools: one pointing to primary, one to replica(s)
- Application routes based on query type
- More complex but centralizes routing logic

**pgpool-II**: Load-balances read queries across multiple replicas automatically.
- Parses SQL to detect read-only vs write queries
- Sends reads to replicas, writes to primary
- Higher operational complexity than PgBouncer

### Replica Lag Tolerance
Applications reading from replicas must handle eventual consistency:

```python
# Pattern: read-your-writes via primary for critical paths
def get_user_after_update(user_id):
    # Critical: must see own write → use primary
    return primary_db.query("SELECT * FROM users WHERE id = ?", user_id)

def get_user_for_display(user_id):
    # Non-critical: replica read is fine
    return replica_db.query("SELECT * FROM users WHERE id = ?", user_id)
```

---

## Sharding Strategies

Sharding horizontally partitions data across multiple independent database instances.

### When to Consider Sharding
- Single-node PostgreSQL can handle 1-5TB comfortably with good hardware
- Consider sharding at >5TB OR >100K writes/sec OR multi-region data locality
- Before sharding: try read replicas, caching, partitioning, hardware upgrades

### Range Sharding
Partition by value ranges of the shard key:

```
Shard 1: user_id 1 - 1,000,000
Shard 2: user_id 1,000,001 - 2,000,000
Shard 3: user_id 2,000,001 - 3,000,000
```

- **Pro**: range queries stay on one shard (efficient)
- **Con**: hot spots (new users always hit latest shard), uneven load
- Good for: time-series data with explicit time-range routing

### Hash Sharding
Apply hash function to shard key → mod by shard count:
```
shard = hash(user_id) % num_shards
```

- **Pro**: even distribution, no hot spots
- **Con**: range queries span all shards (scatter-gather), re-sharding is expensive
- Good for: user data, transactional systems

### Directory-Based (Lookup) Sharding
Maintain a mapping table: shard key → shard ID.

```sql
-- Central routing table
CREATE TABLE shard_map (
  tenant_id BIGINT PRIMARY KEY,
  shard_id  INT NOT NULL
);
```

- **Pro**: flexible, supports moving tenants between shards, easy re-sharding
- **Con**: extra lookup hop, routing table becomes a bottleneck/single point of failure
- Good for: multi-tenant SaaS applications

### Shard Key Selection Criteria
1. **High cardinality**: enough distinct values to distribute load
2. **Even distribution**: values distribute uniformly (avoid skewed keys)
3. **Query locality**: most queries filter on the shard key (minimize cross-shard queries)
4. **Immutable**: shard key should not change (changing it requires data migration)

**Bad shard keys**: `status` (low cardinality), `created_at` without range routing (time-based hot spots), country code (uneven distribution).

**Good shard keys**: `user_id`, `tenant_id`, `organization_id`.

### Hot Spot Avoidance

**Timestamp as shard key problem**: All current writes go to the "current" shard.
```
Bad:  shard = hash(created_at::date) % 4   -- all today's writes → 1 shard
Good: shard = hash(user_id) % 4             -- distributed by user
```

**Sequential IDs**: Similar to timestamp problem for range sharding.
```sql
-- UUID v4 avoids sequential hotspots (random distribution)
-- But: worse cache locality, larger indexes
-- Trade-off: use ULIDs for time-ordered but distributed IDs
```

**Virtual nodes (consistent hashing)**:
```
- Map each physical shard to N virtual nodes (e.g., N=150)
- Hash ring distributes load more evenly
- Adding a shard: only move 1/n of data, not all of it
```

### Cross-Shard Operations
- **Avoid**: JOINs across shards are expensive (application-level merge)
- **Pattern**: denormalize data to make queries shard-local
- **Two-phase commit**: for cross-shard transactions (high latency, avoid if possible)
- **Saga pattern**: for distributed transactions with compensation

---

## Distributed SQL (NewSQL)

For workloads requiring automatic sharding with SQL semantics:

### CockroachDB
- Distributed PostgreSQL-compatible
- Automatic sharding and rebalancing
- Serializable isolation via CRDT + Raft consensus
- Best for: global distribution, automatic geo-partitioning

### YugabyteDB
- PostgreSQL-compatible (YSQL) + Cassandra-compatible (YCQL)
- HTAP: handles both transactional and analytical workloads
- Best for: hybrid OLTP/OLAP, horizontal scale with strong consistency

### TiDB
- MySQL-compatible
- HTAP with columnar storage (TiFlash) for analytics
- Best for: teams on MySQL wanting horizontal scale + analytics

### When to Choose Distributed SQL Over Sharded PostgreSQL
| Criteria | Sharded PG | Distributed SQL |
|----------|-----------|-----------------|
| Data size | < 10TB | > 10TB |
| Global distribution | Complex | Built-in |
| Operational overhead | High (custom routing) | Lower (automatic) |
| PostgreSQL compatibility | Full | Partial (dialect differences) |
| Cost | Lower | Higher |

---

## Re-Sharding

### Gradual Migration with Dual-Write
```
Phase 1: Write to old shard AND new shard (dual-write)
Phase 2: Backfill missing data from old to new
Phase 3: Verify consistency
Phase 4: Switch reads to new shard
Phase 5: Stop writing to old shard
Phase 6: Decommission old shard
```

### Zero-Downtime Re-Sharding with Logical Replication
```sql
-- Set up logical replication from old shard to new
CREATE PUBLICATION reshard_pub FOR TABLE orders;
-- On new shard:
CREATE SUBSCRIPTION reshard_sub CONNECTION '...' PUBLICATION reshard_pub;
-- Let it sync, then cut over
```
