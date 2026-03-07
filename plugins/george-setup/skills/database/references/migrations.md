# Database Migrations Reference

## Migration Tools Overview

| Tool | Language | Approach | Best For |
|------|----------|----------|----------|
| Prisma Migrate | TypeScript | Schema-diff, auto-generate | TypeScript projects using Prisma |
| Alembic | Python | Script-based, autogenerate | SQLAlchemy Python projects |
| Flyway | Any language | SQL-first, versioned | Teams preferring raw SQL migrations |
| Knex.js | JavaScript | JS/TS migration functions | Node.js projects without Prisma |
| golang-migrate | Go | SQL files | Go projects, language-agnostic SQL |

---

## Prisma Migrate

### Core Workflow

```bash
# 1. Modify schema.prisma
# 2. Generate + apply migration (dev only)
npx prisma migrate dev --name descriptive_migration_name
# Creates: prisma/migrations/20251205120000_descriptive_migration_name/migration.sql

# 3. Inspect generated SQL before applying (review it)
cat prisma/migrations/20251205120000_descriptive_migration_name/migration.sql

# 4. Apply in CI/production (no schema changes, no client regeneration)
npx prisma migrate deploy

# Check what's pending
npx prisma migrate status

# Resolve drift (mark a migration as applied without running it)
npx prisma migrate resolve --applied 20251205120000_descriptive_migration_name
```

### Generated Migration SQL Example

```sql
-- prisma/migrations/20251205120000_add_user_profile/migration.sql
-- CreateTable
CREATE TABLE "profiles" (
    "id" TEXT NOT NULL,
    "bio" TEXT,
    "user_id" TEXT NOT NULL,
    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "profiles_user_id_key" ON "profiles"("user_id");

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
```

### Customizing Prisma Migrations

When auto-generated SQL is insufficient, edit the migration file directly after generation:

```sql
-- Custom: backfill data before making column non-nullable
-- Step 1: Add nullable column (auto-generated)
ALTER TABLE "users" ADD COLUMN "display_name" TEXT;

-- Step 2: Backfill (add manually)
UPDATE "users" SET "display_name" = "name" WHERE "display_name" IS NULL;

-- Step 3: Make non-nullable (add manually after backfill)
ALTER TABLE "users" ALTER COLUMN "display_name" SET NOT NULL;
```

---

## Alembic (Python/SQLAlchemy)

### Setup

```bash
# Initialize
alembic init alembic

# alembic.ini: set sqlalchemy.url = postgresql://user:pass@localhost/db
# Or use environment variable in env.py
```

```python
# alembic/env.py
from sqlalchemy import engine_from_config, pool
from app.models import Base  # import your models for autogenerate

target_metadata = Base.metadata

def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix='sqlalchemy.',
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
```

### Creating and Running Migrations

```bash
# Autogenerate from SQLAlchemy model diff
alembic revision --autogenerate -m "add user display_name"
# Creates: alembic/versions/abc123_add_user_display_name.py

# Blank migration (for custom SQL)
alembic revision -m "backfill legacy data"

# Apply all pending migrations
alembic upgrade head

# Apply next N migrations
alembic upgrade +2

# Rollback one step
alembic downgrade -1

# Rollback to specific revision
alembic downgrade abc123

# Show current revision
alembic current

# Show migration history
alembic history --verbose
```

### Migration Script Structure

```python
# alembic/versions/abc123_add_user_display_name.py
"""add user display_name

Revision ID: abc123
Revises: def456
Create Date: 2025-12-05 12:00:00
"""
from alembic import op
import sqlalchemy as sa

revision = 'abc123'
down_revision = 'def456'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: add nullable
    op.add_column('users', sa.Column('display_name', sa.String(255), nullable=True))

    # Step 2: backfill
    op.execute("UPDATE users SET display_name = name WHERE display_name IS NULL")

    # Step 3: make non-nullable
    op.alter_column('users', 'display_name', nullable=False)

    # Add index
    op.create_index('ix_users_display_name', 'users', ['display_name'])


def downgrade() -> None:
    op.drop_index('ix_users_display_name', table_name='users')
    op.drop_column('users', 'display_name')
```

---

## Flyway (SQL-First, Any Language)

### Version Naming Convention

```
V1__create_users_table.sql
V2__add_user_email_index.sql
V3__create_orders_table.sql
V3.1__add_order_status_column.sql  -- hotfix branching
R__refresh_reporting_view.sql      -- repeatable (runs when checksum changes)
U2__undo_add_user_email_index.sql  -- undo script (Flyway Teams)
```

Rules:
- `V` prefix = versioned (runs once, never modified after)
- `R` prefix = repeatable (reruns when file content changes — for views, functions)
- Double underscore `__` separates version from description
- Words separated by underscores or spaces
- **Never modify a versioned migration after it's been applied**

### Example Migration Files

```sql
-- V1__create_users_table.sql
CREATE TABLE users (
    id          VARCHAR(25) PRIMARY KEY,
    email       VARCHAR(255) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

CREATE UNIQUE INDEX users_email_uniq ON users (email);
CREATE INDEX users_created_at_idx ON users (created_at);
```

```sql
-- V2__create_orders_table.sql
CREATE TYPE order_status AS ENUM ('PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED');

CREATE TABLE orders (
    id         VARCHAR(25) PRIMARY KEY,
    user_id    VARCHAR(25) NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    total      NUMERIC(10, 2) NOT NULL,
    status     order_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX orders_user_id_idx ON orders (user_id);
CREATE INDEX orders_status_created_at_idx ON orders (status, created_at);
```

### Running Flyway

```bash
# Apply pending migrations
flyway -url=jdbc:postgresql://localhost/mydb -user=postgres -password=secret migrate

# Check status
flyway info

# Validate checksums match
flyway validate

# Repair checksum mismatch (only for failed migrations, not applied ones)
flyway repair
```

---

## Knex.js Migrations (Node.js)

```javascript
// knexfile.js
module.exports = {
  development: {
    client: 'postgresql',
    connection: process.env.DATABASE_URL,
    migrations: { directory: './migrations', tableName: 'knex_migrations' },
  },
  production: {
    client: 'postgresql',
    connection: process.env.DATABASE_URL,
    pool: { min: 2, max: 10 },
    migrations: { directory: './migrations', tableName: 'knex_migrations' },
  },
};
```

```javascript
// migrations/20251205120000_create_users.js
exports.up = async function(knex) {
  await knex.schema.createTable('users', (table) => {
    table.string('id', 25).primary();
    table.string('email', 255).notNullable().unique();
    table.string('name', 255).notNullable();
    table.timestamp('created_at', { useTz: true }).defaultTo(knex.fn.now());
    table.timestamp('updated_at', { useTz: true }).defaultTo(knex.fn.now());
    table.timestamp('deleted_at', { useTz: true }).nullable();

    table.index(['email']);
    table.index(['created_at']);
  });
};

exports.down = async function(knex) {
  await knex.schema.dropTable('users');
};
```

```bash
npx knex migrate:latest    # apply all pending
npx knex migrate:rollback  # roll back last batch
npx knex migrate:status    # show applied/pending
npx knex migrate:make add_user_avatar  # create new migration file
```

---

## Zero-Downtime Migration Patterns

The key constraint: **migrations run while the old app version is still serving traffic**. A migration that breaks the old code causes downtime.

### The 3-Phase Rule

For any breaking schema change, use 3 sequential deploys:

```
Phase 1: Add new structure (backward-compatible)
  - Deploy migration: add new column/table/index
  - Old code still works (ignores new column)
  - New code reads from new + old column (fallback logic)

Phase 2: Backfill data
  - Run backfill job to populate new column/table
  - Both old and new code can coexist

Phase 3: Remove old structure
  - Deploy migration: drop old column/table
  - Only after confirming no old code reads old column
```

### Adding a Non-Nullable Column

```sql
-- WRONG: this locks the table and breaks old app version
ALTER TABLE users ADD COLUMN display_name VARCHAR(255) NOT NULL;

-- CORRECT: 3 steps
-- Step 1 (deploy with new code that writes display_name):
ALTER TABLE users ADD COLUMN display_name VARCHAR(255);  -- nullable first

-- Step 2 (backfill job — run separately, not in migration):
-- See "Backfill in Batches" below

-- Step 3 (after backfill completes and old code is gone):
ALTER TABLE users ALTER COLUMN display_name SET NOT NULL;
```

### Backfill in Batches

Never run `UPDATE table SET col = val WHERE col IS NULL` on millions of rows — it holds a lock for the duration.

```sql
-- PostgreSQL: cursor-based batch backfill
DO $$
DECLARE
  batch_size INT := 1000;
  last_id VARCHAR := '';
  rows_updated INT;
BEGIN
  LOOP
    UPDATE users
    SET display_name = name
    WHERE id IN (
      SELECT id FROM users
      WHERE display_name IS NULL AND id > last_id
      ORDER BY id
      LIMIT batch_size
    )
    RETURNING id INTO last_id;

    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    EXIT WHEN rows_updated = 0;

    -- Small sleep to reduce lock pressure
    PERFORM pg_sleep(0.01);
  END LOOP;
END $$;
```

```python
# Python backfill script
import time
from sqlalchemy import text

def backfill_display_name(db, batch_size=1000):
    cursor = ''
    total = 0
    while True:
        result = db.execute(text("""
            UPDATE users
            SET display_name = name
            WHERE id IN (
                SELECT id FROM users
                WHERE display_name IS NULL AND id > :cursor
                ORDER BY id
                LIMIT :batch_size
            )
            RETURNING id
        """), {'cursor': cursor, 'batch_size': batch_size})

        rows = result.fetchall()
        if not rows:
            break

        cursor = max(r[0] for r in rows)
        total += len(rows)
        db.commit()
        print(f'Backfilled {total} rows...')
        time.sleep(0.01)

    print(f'Backfill complete: {total} rows updated')
```

### Renaming a Column Safely

```sql
-- Never: ALTER TABLE users RENAME COLUMN email TO email_address;
-- This immediately breaks any code referencing the old name.

-- Phase 1: Add new column
ALTER TABLE users ADD COLUMN email_address VARCHAR(255);
CREATE UNIQUE INDEX CONCURRENTLY users_email_address_uniq ON users (email_address)
    WHERE email_address IS NOT NULL;

-- Phase 2: Backfill + dual-write in application code
UPDATE users SET email_address = email WHERE email_address IS NULL;

-- Phase 3: Make new column non-nullable, remove old column
ALTER TABLE users ALTER COLUMN email_address SET NOT NULL;
ALTER TABLE users DROP COLUMN email;
```

### Adding a Foreign Key on Existing Table

```sql
-- NOT VALID first: add constraint without validating existing rows (instant, non-blocking)
ALTER TABLE orders
  ADD CONSTRAINT orders_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id)
  NOT VALID;

-- Validate separately (takes a SHARE UPDATE EXCLUSIVE lock, not a full table lock)
ALTER TABLE orders VALIDATE CONSTRAINT orders_user_id_fkey;
```

### Concurrent Index Creation (PostgreSQL)

```sql
-- Standard CREATE INDEX locks the table for writes during index build.
-- CONCURRENTLY builds in background — no write lock, but takes longer.
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);

-- Drop with CONCURRENTLY too
DROP INDEX CONCURRENTLY idx_orders_user_id;

-- CONCURRENTLY cannot run inside a transaction block
-- Run it as a standalone statement in the migration script
```

### Soft Delete Pattern

```sql
-- Add soft delete support to existing table
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;

-- Partial index for active records (makes WHERE deleted_at IS NULL fast)
CREATE INDEX CONCURRENTLY users_active_idx ON users (id) WHERE deleted_at IS NULL;

-- Application-level soft delete
UPDATE users SET deleted_at = NOW() WHERE id = $1;

-- Query active records
SELECT * FROM users WHERE deleted_at IS NULL;

-- Periodic hard-delete job (run during off-peak hours)
DELETE FROM users WHERE deleted_at < NOW() - INTERVAL '90 days';
```

### Audit Columns (Standard Pattern)

```sql
-- Add to every table that needs audit trail
ALTER TABLE orders
  ADD COLUMN created_by VARCHAR(25) REFERENCES users(id),
  ADD COLUMN updated_by VARCHAR(25) REFERENCES users(id);

-- Trigger to auto-set updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER orders_set_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

---

## Schema Versioning Best Practices

### Naming Conventions

```
# Format: {timestamp}_{action}_{object}.sql
20251205120000_create_users_table.sql
20251205130000_add_email_index_to_users.sql
20251205140000_create_orders_table.sql
20251206090000_add_status_to_orders.sql
20251210150000_backfill_order_status.sql
20251215120000_drop_legacy_status_column.sql
```

Rules:
- Timestamp prefix ensures chronological ordering
- Action verbs: `create`, `add`, `drop`, `rename`, `backfill`, `alter`
- Descriptive enough to understand purpose without reading the SQL
- One logical change per migration file

### Rollback Strategies

**Prefer forward migrations** (rollback by deploying a new migration that reverses changes):

```sql
-- Instead of complex downgrade scripts, write a forward fix:
-- If V5 added a column that broke things, V6 drops it
-- V6__drop_broken_column.sql
ALTER TABLE users DROP COLUMN IF EXISTS broken_col;
```

**When to write downgrade migrations:**
- During active development before first production deploy
- For high-risk schema changes where quick rollback is critical
- Flyway Teams: U (undo) scripts

**Downgrade migration example (Alembic):**

```python
def downgrade() -> None:
    # Reverse the upgrade — must be safe to run after data has been written
    # If upgrade added a NOT NULL column, downgrade must drop it
    # (cannot make it nullable without data loss risk)
    op.drop_index('ix_users_display_name', table_name='users')
    op.drop_column('users', 'display_name')
    # Note: if data was backfilled, dropping the column loses it permanently
```

### Testing Migrations

```bash
# Test against a copy of production data
pg_dump production_db | psql test_db
cd app && DATABASE_URL=postgresql://localhost/test_db npx prisma migrate deploy

# Verify migration is idempotent (safe to run twice)
DATABASE_URL=postgresql://localhost/test_db npx prisma migrate deploy  # should be no-op

# Run application tests against migrated schema
DATABASE_URL=postgresql://localhost/test_db npm test
```

### CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
jobs:
  migrate:
    steps:
      - name: Run migrations
        run: npx prisma migrate deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}

      - name: Verify migration status
        run: npx prisma migrate status

      - name: Deploy application
        # Only runs if migration succeeds
        run: ...
```

### Blue-Green Migration Strategy

For high-risk migrations, use blue-green deployments:

```
1. Spin up Green environment (new app version) pointing to same DB
2. Apply backward-compatible migration (Phase 1)
3. Verify Green is healthy
4. Shift traffic from Blue to Green
5. Keep Blue running for 15 minutes (instant rollback window)
6. Decommission Blue
7. Apply Phase 3 cleanup migration (now safe — no old code running)
```

This avoids the problem of running migrations while old app code is still active.
