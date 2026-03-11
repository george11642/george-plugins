# Data Modeling Reference

## Normalization Forms

Normalization eliminates redundancy and update anomalies. Start here; denormalize only when you have measured performance problems.

### First Normal Form (1NF)

**Rule**: Each column holds a single atomic value. No repeating groups. Primary key exists.

```sql
-- VIOLATES 1NF: phone_numbers is multi-valued
CREATE TABLE customers_bad (
    id        INT PRIMARY KEY,
    name      VARCHAR(100),
    phones    VARCHAR(200)  -- "555-1234, 555-5678" — multiple values in one column
);

-- 1NF: extract repeating group to separate table
CREATE TABLE customers (
    id   INT PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE customer_phones (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    phone       VARCHAR(20) NOT NULL,
    type        VARCHAR(20) NOT NULL  -- 'mobile', 'home', 'work'
);
```

### Second Normal Form (2NF)

**Rule**: Must be in 1NF. Every non-key column must depend on the **entire** primary key (eliminates partial dependencies — only relevant when PK is composite).

```sql
-- VIOLATES 2NF: composite PK is (order_id, product_id)
-- product_name depends only on product_id, not the full composite key
CREATE TABLE order_items_bad (
    order_id     INT,
    product_id   INT,
    product_name VARCHAR(100),  -- partial dependency on product_id only
    quantity     INT,
    PRIMARY KEY (order_id, product_id)
);

-- 2NF: move product_name to products table
CREATE TABLE products (
    id   INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE order_items (
    order_id   INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    quantity   INT NOT NULL,
    PRIMARY KEY (order_id, product_id)
);
```

### Third Normal Form (3NF)

**Rule**: Must be in 2NF. No non-key column depends on another non-key column (eliminates transitive dependencies).

```sql
-- VIOLATES 3NF: zip_code → city → state (transitive dependency)
CREATE TABLE employees_bad (
    id         INT PRIMARY KEY,
    name       VARCHAR(100),
    zip_code   VARCHAR(10),
    city       VARCHAR(100),   -- depends on zip_code, not id
    state      VARCHAR(2)      -- depends on zip_code, not id
);

-- 3NF: extract zip code data
CREATE TABLE zip_codes (
    zip_code VARCHAR(10) PRIMARY KEY,
    city     VARCHAR(100) NOT NULL,
    state    VARCHAR(2) NOT NULL
);

CREATE TABLE employees (
    id       INT PRIMARY KEY,
    name     VARCHAR(100),
    zip_code VARCHAR(10) REFERENCES zip_codes(zip_code)
);
```

### Boyce-Codd Normal Form (BCNF)

**Rule**: Stricter than 3NF. Every determinant must be a candidate key. Handles edge cases with overlapping composite keys.

```sql
-- Example: students can take a course from multiple teachers;
-- each teacher teaches only one course; each student takes a course from one teacher.
-- student_id + course determines teacher; teacher determines course (violation)

-- VIOLATES BCNF
CREATE TABLE enrollment_bad (
    student_id INT,
    course     VARCHAR(50),
    teacher    VARCHAR(50),   -- teacher → course (teacher is a determinant but not a key)
    PRIMARY KEY (student_id, course)
);

-- BCNF: decompose
CREATE TABLE teacher_courses (
    teacher VARCHAR(50) PRIMARY KEY,
    course  VARCHAR(50) NOT NULL
);

CREATE TABLE student_teachers (
    student_id INT,
    teacher    VARCHAR(50) REFERENCES teacher_courses(teacher),
    PRIMARY KEY (student_id, teacher)
);
```

---

## When to Denormalize

Denormalization trades write complexity for read performance. Always measure first.

| Signal | Denormalization Candidate |
|--------|--------------------------|
| Dashboard query JOINs 5+ tables | Materialized summary table |
| Report recalculates same aggregate every request | Cached aggregate column |
| Hot path reads 3+ tables per request | Embed redundant data |
| Full-text search across joined fields | Denormalized text column + index |

```sql
-- Example: order total is always SUM of items, but recalculating is expensive
-- Denormalize: store total on orders table, update via trigger or application

CREATE TABLE orders (
    id         INT PRIMARY KEY,
    user_id    INT NOT NULL REFERENCES users(id),
    total      NUMERIC(10,2) NOT NULL DEFAULT 0,  -- denormalized
    item_count INT NOT NULL DEFAULT 0,             -- denormalized
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Keep in sync with trigger
CREATE OR REPLACE FUNCTION update_order_totals()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE orders
  SET
    total      = (SELECT COALESCE(SUM(price * quantity), 0) FROM order_items WHERE order_id = NEW.order_id),
    item_count = (SELECT COUNT(*) FROM order_items WHERE order_id = NEW.order_id)
  WHERE id = NEW.order_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_items_totals
  AFTER INSERT OR UPDATE OR DELETE ON order_items
  FOR EACH ROW EXECUTE FUNCTION update_order_totals();
```

---

## Relationship Types

### One-to-One

```sql
-- SQL: always use a foreign key with UNIQUE constraint
-- Decision: embed vs reference
--   Embed (same table): data is always accessed together, tight coupling is ok
--   Reference (separate table): optional data, security boundary, or large fields

-- Reference pattern (profiles optionally extend users)
CREATE TABLE users (
    id    VARCHAR(25) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name  VARCHAR(255) NOT NULL
);

CREATE TABLE user_profiles (
    id         VARCHAR(25) PRIMARY KEY,
    user_id    VARCHAR(25) UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bio        TEXT,
    avatar_url VARCHAR(500),
    birth_date DATE
);
```

### One-to-Many

```sql
-- Always use a foreign key (reference, never embed in SQL)
-- The "many" side holds the FK

CREATE TABLE posts (
    id        VARCHAR(25) PRIMARY KEY,
    author_id VARCHAR(25) NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    title     VARCHAR(255) NOT NULL,
    content   TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index the FK column — critical for JOIN performance
CREATE INDEX posts_author_id_idx ON posts (author_id);

-- If cascade delete is desired:
-- ON DELETE CASCADE  — delete posts when user is deleted
-- ON DELETE RESTRICT — prevent user deletion if posts exist (default)
-- ON DELETE SET NULL — set author_id to NULL (requires nullable column)
```

### Many-to-Many

```sql
-- Requires a junction (bridge) table
-- Junction table can carry attributes about the relationship itself

-- Simple junction (no relationship attributes)
CREATE TABLE post_tags (
    post_id VARCHAR(25) NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    tag_id  VARCHAR(25) NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);

-- Index for reverse lookup (find all posts for a tag)
CREATE INDEX post_tags_tag_id_idx ON post_tags (tag_id);

-- Junction with relationship attributes
CREATE TABLE user_roles (
    user_id    VARCHAR(25) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id    VARCHAR(25) NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by VARCHAR(25) REFERENCES users(id),
    expires_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, role_id)
);

-- When relationship itself has an ID (for FK references)
CREATE TABLE order_promotions (
    id           VARCHAR(25) PRIMARY KEY,  -- own ID for referencing
    order_id     VARCHAR(25) NOT NULL REFERENCES orders(id),
    promotion_id VARCHAR(25) NOT NULL REFERENCES promotions(id),
    discount     NUMERIC(10,2) NOT NULL,
    applied_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (order_id, promotion_id)
);
```

---

## Schema Design Patterns

### Soft Deletes

```sql
-- Add deleted_at to tables that need audit trail
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;

-- Partial index for active records — makes WHERE deleted_at IS NULL fast
CREATE INDEX users_active_idx ON users (id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX users_email_active_uniq ON users (email) WHERE deleted_at IS NULL;
-- Note: unique index only on active records allows email reuse after soft delete

-- Soft delete (application layer)
UPDATE users SET deleted_at = NOW() WHERE id = $1;

-- Query active records
SELECT * FROM users WHERE deleted_at IS NULL;

-- PostgreSQL Row Level Security for transparent filtering
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_active ON users
    USING (deleted_at IS NULL);
```

### Temporal Data (Effective Date Ranges)

```sql
-- Bi-temporal table: track when a record was valid AND when we knew about it
CREATE TABLE price_history (
    id           VARCHAR(25) PRIMARY KEY,
    product_id   VARCHAR(25) NOT NULL REFERENCES products(id),
    price        NUMERIC(10, 2) NOT NULL,
    -- Valid time: when this price was actually in effect
    valid_from   TIMESTAMPTZ NOT NULL,
    valid_to     TIMESTAMPTZ,  -- NULL = currently valid
    -- System time: when we recorded this fact
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX price_history_product_valid_idx
    ON price_history (product_id, valid_from, valid_to);

-- Query: price at a specific point in time
SELECT * FROM price_history
WHERE product_id = $1
  AND valid_from <= $2
  AND (valid_to IS NULL OR valid_to > $2)
ORDER BY valid_from DESC
LIMIT 1;

-- Close out current record and insert new one (application layer)
BEGIN;
UPDATE price_history
  SET valid_to = NOW()
  WHERE product_id = $1 AND valid_to IS NULL;

INSERT INTO price_history (id, product_id, price, valid_from)
  VALUES (gen_random_uuid(), $1, $2, NOW());
COMMIT;
```

### Enum vs Lookup Table

| Use Enum | Use Lookup Table |
|----------|-----------------|
| Values are fixed and change rarely | Values may be added/removed at runtime |
| Values have meaning in code | Business users manage values |
| 3–10 values | Many values or hierarchical |
| No additional attributes needed | Values have display labels, sort order, metadata |

```sql
-- PostgreSQL enum (fast, type-safe, but ALTER is expensive)
CREATE TYPE order_status AS ENUM ('PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED');

ALTER TABLE orders ADD COLUMN status order_status NOT NULL DEFAULT 'PENDING';

-- Add a new enum value (PostgreSQL: only can add, not remove or rename without full rebuild)
ALTER TYPE order_status ADD VALUE 'REFUNDED' AFTER 'DELIVERED';

-- Lookup table (flexible, allows metadata, manageable at runtime)
CREATE TABLE order_statuses (
    code        VARCHAR(20) PRIMARY KEY,  -- 'PENDING', 'CONFIRMED', etc.
    label       VARCHAR(100) NOT NULL,     -- human-readable label
    description TEXT,
    sort_order  INT NOT NULL DEFAULT 0,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE orders ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
    REFERENCES order_statuses(code);
```

### Generated/Computed Columns (PostgreSQL)

```sql
-- STORED computed column: persisted to disk, updated on INSERT/UPDATE
-- Good for: search vectors, derived values used in indexes

ALTER TABLE products ADD COLUMN search_vector TSVECTOR
    GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, ''))
    ) STORED;

CREATE INDEX products_search_idx ON products USING GIN (search_vector);

-- Query full-text search
SELECT *, ts_rank(search_vector, query) AS rank
FROM products, to_tsquery('english', 'laptop & portable') query
WHERE search_vector @@ query
ORDER BY rank DESC;

-- VIRTUAL (not stored) — computed on read, no storage cost
-- Note: PostgreSQL only supports STORED. MySQL/SQLite support VIRTUAL.
```

### JSONB for Flexible Attributes

```sql
-- Use JSONB when: schema is genuinely unpredictable per row, or
-- you have sparse optional attributes that vary per entity type
-- Do NOT use as a substitute for proper columns on frequently-queried fields

CREATE TABLE products (
    id         VARCHAR(25) PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    price      NUMERIC(10, 2) NOT NULL,
    -- Fixed attributes: separate columns (indexed, typed, queryable)
    category   VARCHAR(50),
    -- Variable attributes: JSONB (flexible, but no FK, no type constraints)
    attributes JSONB DEFAULT '{}'::JSONB
);

-- Index a specific JSONB key (expression index)
CREATE INDEX products_brand_idx ON products ((attributes->>'brand'));

-- Index for any key lookup (GIN — more flexible, larger)
CREATE INDEX products_attributes_gin ON products USING GIN (attributes);

-- Query JSONB
SELECT * FROM products WHERE attributes->>'brand' = 'Apple';
SELECT * FROM products WHERE attributes @> '{"color": "red", "size": "L"}';
SELECT * FROM products WHERE attributes ? 'warranty_months';

-- Update specific key
UPDATE products
SET attributes = jsonb_set(attributes, '{color}', '"blue"')
WHERE id = $1;

-- Extract to separate column when query pattern becomes hot
-- ALTER TABLE products ADD COLUMN brand VARCHAR(100) GENERATED ALWAYS AS (attributes->>'brand') STORED;
```

---

## Multi-Tenant Data Isolation

### Tenant Column + Row Level Security

Simplest approach. All tenants share tables; RLS enforces isolation.

```sql
-- Add tenant_id to all shared tables
ALTER TABLE users ADD COLUMN tenant_id VARCHAR(25) NOT NULL REFERENCES tenants(id);
ALTER TABLE orders ADD COLUMN tenant_id VARCHAR(25) NOT NULL REFERENCES tenants(id);

-- Composite indexes: always include tenant_id first
CREATE INDEX users_tenant_email_idx ON users (tenant_id, email);
CREATE INDEX orders_tenant_created_idx ON orders (tenant_id, created_at);
CREATE UNIQUE INDEX users_tenant_email_uniq ON users (tenant_id, email);

-- Row Level Security policy
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON users
    USING (tenant_id = current_setting('app.tenant_id'));

CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.tenant_id'));

-- Set context at session start (before first query)
SET LOCAL app.tenant_id = 'tenant_abc';
```

```python
# SQLAlchemy: set tenant context per request
from sqlalchemy import event, text

@event.listens_for(Session, 'after_begin')
def set_tenant_context(session, transaction, connection):
    tenant_id = get_current_tenant_id()  # from request context
    connection.execute(text(f"SET LOCAL app.tenant_id = :tid"), {'tid': tenant_id})
```

### Separate Schema Per Tenant (PostgreSQL)

Stronger isolation. Each tenant gets their own schema (`tenant_abc.users`, `tenant_def.users`).

```sql
-- Create tenant schema
CREATE SCHEMA tenant_abc;

-- Duplicate tables into schema (or use search_path)
SET search_path = tenant_abc, public;
CREATE TABLE users (LIKE public.users INCLUDING ALL);

-- Query tenant data by setting search_path
SET search_path = tenant_abc;
SELECT * FROM users WHERE email = $1;
```

**Trade-offs:**
- Pro: complete schema isolation, independent migrations per tenant
- Con: connection pooling complexity (PgBouncer ties connections to search_path), schema explosion at scale (>1000 tenants becomes unmanageable)

### Separate Database Per Tenant

Maximum isolation. Each tenant has their own database instance.

```
Pros: hardware isolation, independent backup/restore, no RLS complexity
Cons: connection pooling doesn't work across databases, operational overhead scales linearly,
      cross-tenant analytics requires ETL, expensive at large tenant count (>100)

Use when: enterprise customers, regulatory compliance (HIPAA, SOC2), custom SLAs
```

---

## Data Warehouse Patterns

### Star Schema

```sql
-- Fact table: records events/transactions (large, append-only, foreign keys to dims)
CREATE TABLE fact_orders (
    order_id       VARCHAR(25) NOT NULL,
    -- Dimension keys
    user_id        VARCHAR(25) NOT NULL,
    product_id     VARCHAR(25) NOT NULL,
    date_id        INT NOT NULL,          -- YYYYMMDD integer key
    -- Measures
    quantity       INT NOT NULL,
    unit_price     NUMERIC(10, 2) NOT NULL,
    discount       NUMERIC(10, 2) NOT NULL DEFAULT 0,
    gross_amount   NUMERIC(10, 2) NOT NULL,
    net_amount     NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
) PARTITION BY RANGE (date_id);

-- Dimension tables: descriptive attributes (smaller, slowly changing)
CREATE TABLE dim_users (
    user_key    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- surrogate key
    user_id     VARCHAR(25) NOT NULL,   -- natural key from source system
    email       VARCHAR(255) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    segment     VARCHAR(50),
    country     VARCHAR(2),
    -- SCD Type 2 columns (see below)
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to   TIMESTAMPTZ,
    is_current     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE dim_date (
    date_id     INT PRIMARY KEY,  -- YYYYMMDD
    date        DATE NOT NULL,
    year        INT NOT NULL,
    quarter     INT NOT NULL,
    month       INT NOT NULL,
    week        INT NOT NULL,
    day_of_week INT NOT NULL,
    is_weekend  BOOLEAN NOT NULL,
    is_holiday  BOOLEAN NOT NULL DEFAULT FALSE
);
```

### Slowly Changing Dimensions (SCD)

**SCD Type 1**: Overwrite (no history — use for corrections, non-important changes)

```sql
UPDATE dim_users SET email = 'new@email.com', name = 'New Name' WHERE user_id = $1;
```

**SCD Type 2**: Add new row (full history — use when historical accuracy matters)

```sql
-- Close current record
UPDATE dim_users
SET effective_to = NOW(), is_current = FALSE
WHERE user_id = $1 AND is_current = TRUE;

-- Insert new current record
INSERT INTO dim_users (user_id, email, name, segment, country, effective_from, is_current)
VALUES ($1, $2, $3, $4, $5, NOW(), TRUE);

-- Query: current state
SELECT * FROM dim_users WHERE user_id = $1 AND is_current = TRUE;

-- Query: state at a point in time
SELECT * FROM dim_users
WHERE user_id = $1
  AND effective_from <= $2
  AND (effective_to IS NULL OR effective_to > $2);
```

**SCD Type 3**: Add column for previous value (limited history — use when only "previous" matters)

```sql
ALTER TABLE dim_users
  ADD COLUMN previous_segment VARCHAR(50),
  ADD COLUMN segment_changed_at TIMESTAMPTZ;

UPDATE dim_users
SET previous_segment = segment,
    segment_changed_at = NOW(),
    segment = 'Enterprise'
WHERE user_id = $1;
```

### Event Sourcing Basics

```sql
-- Events are immutable facts; current state is derived by replaying events
CREATE TABLE domain_events (
    id             VARCHAR(25) PRIMARY KEY,
    aggregate_type VARCHAR(50) NOT NULL,   -- 'Order', 'User', 'Product'
    aggregate_id   VARCHAR(25) NOT NULL,   -- ID of the entity this event belongs to
    event_type     VARCHAR(100) NOT NULL,  -- 'OrderPlaced', 'OrderShipped', 'OrderCancelled'
    event_data     JSONB NOT NULL,         -- event payload
    metadata       JSONB NOT NULL DEFAULT '{}',
    sequence_num   BIGINT NOT NULL,        -- monotonically increasing per aggregate
    occurred_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by     VARCHAR(25),
    correlation_id VARCHAR(25),            -- trace across service boundaries

    UNIQUE (aggregate_id, sequence_num)
);

CREATE INDEX events_aggregate_idx ON domain_events (aggregate_type, aggregate_id, sequence_num);
CREATE INDEX events_type_idx ON domain_events (event_type, occurred_at);

-- Snapshot table (optimization: don't replay all events every time)
CREATE TABLE aggregate_snapshots (
    aggregate_id   VARCHAR(25) NOT NULL,
    aggregate_type VARCHAR(50) NOT NULL,
    sequence_num   BIGINT NOT NULL,        -- events up to this point are captured in snapshot
    state          JSONB NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (aggregate_id, sequence_num)
);

-- Replay events for an aggregate (from last snapshot)
SELECT e.*
FROM domain_events e
WHERE e.aggregate_id = $1
  AND e.sequence_num > (
    SELECT COALESCE(MAX(sequence_num), 0)
    FROM aggregate_snapshots
    WHERE aggregate_id = $1
  )
ORDER BY e.sequence_num;
```

---

## ER Diagram Conventions

### Cardinality Notation (Crow's Foot)

```
One (and only one):     |——|
One or zero (optional): |——O
Many (one or more):     |——<
Many or zero:           |——O<
Exactly one:            ||——||

Examples:
  users ||——O< orders        (one user has zero or many orders)
  orders ||——|< order_items  (one order has one or many items)
  users ||——O| profiles      (one user has zero or one profile)
  posts >O——O< tags          (many posts have many tags, both optional)
```

### Identifying vs Non-Identifying Relationships

```sql
-- Identifying: child PK includes parent FK (child "depends on" parent for identity)
-- Use: junction tables, line items where row makes no sense without parent
CREATE TABLE order_items (
    order_id   VARCHAR(25) REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(25) REFERENCES products(id),
    quantity   INT NOT NULL,
    PRIMARY KEY (order_id, product_id)  -- composite PK includes FK
);

-- Non-identifying: child has own PK; parent FK is just a foreign key
-- Use: independent entities that happen to be related
CREATE TABLE posts (
    id        VARCHAR(25) PRIMARY KEY,   -- own identity
    author_id VARCHAR(25) REFERENCES users(id) ON DELETE SET NULL,
    title     VARCHAR(255) NOT NULL
);
```

### Key Design Decisions

```sql
-- Natural vs Surrogate keys
-- Natural key: meaningful business identifier (email, SSN, ISBN)
--   Pro: no extra join, readable, enforces uniqueness naturally
--   Con: can change, can be long (bad for FK performance)

-- Surrogate key: generated system identifier (UUID, CUID, serial integer)
--   Pro: stable, compact, decoupled from business logic
--   Con: extra column, opaque

-- Use CUID2 or UUID for distributed systems (globally unique, no coordination)
-- Use BIGSERIAL/IDENTITY for single-node systems (compact, sortable, fast B-tree)

-- UUID vs CUID2:
-- UUID v4: random, not sortable — causes index fragmentation in PostgreSQL
-- UUID v7: timestamp-prefixed, sortable — better for PK indexes
-- CUID2: shorter, sortable, URL-safe — good balance

-- Integer sequences: fast, compact, sortable, but predictable (enumerable by ID)
CREATE TABLE products (
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);
```

---

## Composite Keys and Constraints

```sql
-- Unique constraint across multiple columns
ALTER TABLE user_roles ADD CONSTRAINT user_roles_uniq UNIQUE (user_id, role_id);

-- Check constraints
ALTER TABLE orders ADD CONSTRAINT orders_positive_total CHECK (total >= 0);
ALTER TABLE products ADD CONSTRAINT products_stock_non_negative CHECK (stock >= 0);
ALTER TABLE events ADD CONSTRAINT events_date_range CHECK (ends_at > starts_at);

-- Exclusion constraints (PostgreSQL — prevent overlapping ranges)
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room_bookings (
    id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id  INT NOT NULL REFERENCES rooms(id),
    during   TSTZRANGE NOT NULL,
    EXCLUDE USING GIST (room_id WITH =, during WITH &&)
    -- Prevents double-booking: same room, overlapping time range
);
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Why It Hurts | Fix |
|-------------|-------------|-----|
| EAV (Entity-Attribute-Value) table | No type safety, no FK constraints, terrible query performance | JSONB for flexible attributes, or proper columns |
| Storing comma-separated IDs | Cannot use FK constraints, terrible for JOINs | Junction table |
| `status` as INT/magic number | Unreadable, no enforced range | ENUM or lookup table with VARCHAR code |
| No timestamps on any table | Cannot reconstruct history, debug incidents | Add `created_at`, `updated_at` to every table |
| Recursive adjacency list without indexed depth | Hierarchical queries O(n) per level | Use `ltree` extension or closure table for deep hierarchies |
| Storing computed aggregates without trigger/constraint | Data drift between sum and items | Either compute on read or enforce with trigger |
| UUID v4 as primary key on large tables | Random inserts cause B-tree fragmentation | Use UUID v7 or CUID2 (time-ordered) |
| Nullable boolean columns | Three-state logic (`TRUE`/`FALSE`/`NULL`) is confusing | Use `NOT NULL DEFAULT FALSE` or separate `nullable_flag` |
