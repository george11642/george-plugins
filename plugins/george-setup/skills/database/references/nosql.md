# NoSQL Reference

## MongoDB

### Document Design Principles
- **Embed** data that is always accessed together (1:1, 1:few relationships).
- **Reference** data that is accessed independently, changes frequently, or grows unbounded.
- **Never embed unbounded arrays.** A document has a 16MB limit. Use bucketing or reference patterns.

### Schema Patterns
```javascript
// Embed: order with line items (always accessed together)
{
  _id: ObjectId("..."),
  customer_id: ObjectId("..."),
  items: [
    { product: "Widget", qty: 2, price: 9.99 },
    { product: "Gadget", qty: 1, price: 24.99 }
  ],
  total: 44.97,
  created_at: ISODate("2025-03-01")
}

// Reference: user with many orders (unbounded relationship)
// users collection
{ _id: ObjectId("u1"), name: "Alice", email: "alice@example.com" }
// orders collection
{ _id: ObjectId("o1"), user_id: ObjectId("u1"), total: 44.97 }

// Bucket pattern: time-series data (group by hour/day)
{
  sensor_id: "temp-001",
  date: ISODate("2025-03-01"),
  readings: [
    { time: ISODate("2025-03-01T00:00:00Z"), value: 22.5 },
    { time: ISODate("2025-03-01T00:01:00Z"), value: 22.6 }
  ],
  count: 2,
  sum: 45.1
}
```

### Indexing
```javascript
// Compound index (ESR rule: Equality, Sort, Range)
db.orders.createIndex({ status: 1, created_at: -1, total: 1 });

// Text index for search
db.articles.createIndex({ title: "text", body: "text" });

// Partial index (only index matching documents)
db.orders.createIndex(
  { created_at: 1 },
  { partialFilterExpression: { status: "pending" } }
);

// TTL index (auto-delete after expiry)
db.sessions.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600 });

// Wildcard index (dynamic schemas)
db.events.createIndex({ "metadata.$**": 1 });
```

### Aggregation Pipeline
```javascript
db.orders.aggregate([
  { $match: { status: "completed", created_at: { $gte: ISODate("2025-01-01") } } },
  { $group: {
    _id: { month: { $month: "$created_at" }, product: "$items.product" },
    revenue: { $sum: "$total" },
    count: { $sum: 1 }
  }},
  { $sort: { revenue: -1 } },
  { $limit: 10 },
  { $lookup: {
    from: "products",
    localField: "_id.product",
    foreignField: "name",
    as: "product_info"
  }}
]);
```

### Transactions
MongoDB 4.0+ supports multi-document transactions. Use sparingly — they add latency.
```javascript
const session = client.startSession();
session.withTransaction(async () => {
  await accounts.updateOne({ _id: from }, { $inc: { balance: -amount } }, { session });
  await accounts.updateOne({ _id: to }, { $inc: { balance: amount } }, { session });
  await transfers.insertOne({ from, to, amount, date: new Date() }, { session });
});
```

## Redis

### Data Structure Selection
| Structure | Use Case | Example |
|-----------|----------|---------|
| String | Cache, counters, flags | Session tokens, page views |
| Hash | Object storage | User profiles, config |
| List | Queues, recent items | Job queues, activity feeds |
| Set | Unique collections, tags | Online users, permissions |
| Sorted Set | Rankings, time-series | Leaderboards, rate limiting |
| Stream | Event log, pub/sub | Event sourcing, message queues |

### Common Patterns
```redis
# Cache with TTL
SET user:123:profile '{"name":"Alice"}' EX 3600

# Counter with atomic increment
INCR page:views:homepage
INCRBY user:123:points 50

# Rate limiting (sliding window)
MULTI
ZADD ratelimit:user:123 <now_ms> <request_id>
ZREMRANGEBYSCORE ratelimit:user:123 0 <now_ms - window_ms>
ZCARD ratelimit:user:123
EXPIRE ratelimit:user:123 <window_seconds>
EXEC

# Leaderboard
ZADD leaderboard 1500 "player:alice"
ZADD leaderboard 2200 "player:bob"
ZREVRANGE leaderboard 0 9 WITHSCORES      # top 10
ZREVRANK leaderboard "player:alice"         # rank of alice

# Distributed lock (use Redlock for multi-node)
SET lock:order:123 <token> NX EX 30
# Release only if you own the lock
# Use Lua script: if redis.call("get",KEYS[1]) == ARGV[1] then return redis.call("del",KEYS[1]) end

# Pub/Sub
SUBSCRIBE channel:notifications
PUBLISH channel:notifications '{"event":"new_order","id":456}'
```

### Cache Strategies
- **Cache-Aside**: App checks cache, on miss reads DB and populates cache. Most common.
- **Write-Through**: App writes to cache, cache writes to DB. Ensures consistency.
- **Write-Behind**: App writes to cache, cache async-writes to DB. Better write performance, risk of data loss.
- **Cache stampede prevention**: Use probabilistic early expiration or distributed locks on cache misses.

## DynamoDB

### Single-Table Design
Store all entities in one table. Design access patterns first, then define keys.

```
| PK              | SK                    | Type    | Data...          |
|-----------------|-----------------------|---------|------------------|
| USER#alice      | PROFILE               | User    | name, email      |
| USER#alice      | ORDER#2025-03-01#001  | Order   | total, status    |
| USER#alice      | ORDER#2025-03-01#002  | Order   | total, status    |
| PRODUCT#widget  | METADATA              | Product | price, stock     |
| PRODUCT#widget  | REVIEW#alice          | Review  | rating, comment  |
```

### Access Patterns
```
Get user profile:       PK = "USER#alice", SK = "PROFILE"
List user orders:       PK = "USER#alice", SK begins_with("ORDER#")
Orders by date range:   PK = "USER#alice", SK between("ORDER#2025-01", "ORDER#2025-03")
Product reviews:        PK = "PRODUCT#widget", SK begins_with("REVIEW#")
```

### GSI (Global Secondary Index)
Use GSIs to support additional access patterns. Design GSI keys just like table keys.

```
GSI1: PK = status, SK = created_at
  → Query all orders by status sorted by date

GSI2: PK = product_id, SK = rating
  → Query reviews by product sorted by rating
```

### Key Design Rules
1. **High-cardinality partition keys.** Avoid hot partitions — distribute writes evenly.
2. **Composite sort keys** enable range queries and hierarchical data.
3. **Overload keys** — PK and SK hold different entity types (single-table design).
4. **Use GSIs sparingly** — each GSI duplicates data and costs write capacity.
5. **Prefer query over scan.** Scans read the entire table. Design keys to support queries.

### Capacity and Pricing
- **On-demand**: Pay per request. Use for unpredictable or spiky workloads.
- **Provisioned**: Set RCU/WCU. Use for predictable workloads with auto-scaling.
- **DAX (DynamoDB Accelerator)**: In-memory cache for microsecond reads. Use for read-heavy, latency-sensitive patterns.
