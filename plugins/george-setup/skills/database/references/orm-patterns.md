# ORM Patterns Reference

## Prisma (Schema-First, TypeScript)

### Schema Structure

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  deletedAt DateTime?

  posts     Post[]
  profile   Profile?
  orders    Order[]

  @@index([email])
  @@index([createdAt])
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  authorId  String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  author    User     @relation(fields: [authorId], references: [id], onDelete: Cascade)
  tags      Tag[]    @relation("PostTags")

  @@index([authorId])
  @@index([published, createdAt])
}

model Tag {
  id    String @id @default(cuid())
  name  String @unique
  posts Post[] @relation("PostTags")
}

model Profile {
  id     String  @id @default(cuid())
  bio    String?
  userId String  @unique
  user   User    @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model Order {
  id         String      @id @default(cuid())
  total      Decimal     @db.Decimal(10, 2)
  status     OrderStatus @default(PENDING)
  userId     String
  createdAt  DateTime    @default(now())

  user       User        @relation(fields: [userId], references: [id])
  items      OrderItem[]

  @@index([userId, status])
  @@index([createdAt])
}

enum OrderStatus {
  PENDING
  CONFIRMED
  SHIPPED
  DELIVERED
  CANCELLED
}

model OrderItem {
  id        String  @id @default(cuid())
  orderId   String
  productId String
  quantity  Int
  price     Decimal @db.Decimal(10, 2)

  order     Order   @relation(fields: [orderId], references: [id], onDelete: Cascade)

  @@index([orderId])
}
```

### CRUD with Prisma Client

```typescript
import { PrismaClient, Prisma } from '@prisma/client';

const prisma = new PrismaClient({
  log: ['query', 'warn', 'error'],
});

// --- CREATE ---
const user = await prisma.user.create({
  data: {
    email: 'alice@example.com',
    name: 'Alice',
    profile: {
      create: { bio: 'Software engineer' },
    },
  },
  include: { profile: true },
});

// createMany (no nested writes, faster for bulk inserts)
await prisma.user.createMany({
  data: [
    { email: 'bob@example.com', name: 'Bob' },
    { email: 'carol@example.com', name: 'Carol' },
  ],
  skipDuplicates: true,
});

// --- READ ---
// findUnique — guaranteed single result or null
const byId = await prisma.user.findUnique({ where: { id: 'abc123' } });

// findFirst — first matching row (non-unique conditions)
const firstActive = await prisma.user.findFirst({
  where: { deletedAt: null },
  orderBy: { createdAt: 'desc' },
});

// findMany — collection with filtering, sorting, pagination
const users = await prisma.user.findMany({
  where: {
    deletedAt: null,
    email: { endsWith: '@company.com' },
    createdAt: { gte: new Date('2025-01-01') },
  },
  orderBy: { createdAt: 'desc' },
  skip: 0,
  take: 20,
  select: {
    id: true,
    email: true,
    name: true,
    // _count for aggregation without loading relations
    _count: { select: { orders: true } },
  },
});

// count
const total = await prisma.user.count({ where: { deletedAt: null } });

// --- UPDATE ---
const updated = await prisma.user.update({
  where: { id: 'abc123' },
  data: { name: 'Alice Smith' },
});

// updateMany — no return of updated rows in PostgreSQL by default
const { count } = await prisma.user.updateMany({
  where: { deletedAt: { not: null } },
  data: { name: '[deleted]' },
});

// --- UPSERT ---
const upserted = await prisma.user.upsert({
  where: { email: 'alice@example.com' },
  create: { email: 'alice@example.com', name: 'Alice' },
  update: { name: 'Alice Updated' },
});

// --- DELETE ---
await prisma.user.delete({ where: { id: 'abc123' } });

await prisma.user.deleteMany({
  where: { deletedAt: { lt: new Date('2024-01-01') } },
});
```

### Include vs Select

```typescript
// include: eager-load relations (fetches full relation objects)
// Use when you need the full related object
const postWithAuthor = await prisma.post.findUnique({
  where: { id: 'post1' },
  include: {
    author: true,          // full User object
    tags: true,            // array of Tag objects
    _count: { select: { tags: true } },
  },
});

// select: pick specific fields (more efficient — avoids over-fetching)
// Use when you know exactly which fields you need
const postSummary = await prisma.post.findMany({
  where: { published: true },
  select: {
    id: true,
    title: true,
    createdAt: true,
    author: {
      select: { id: true, name: true },  // nested select on relation
    },
  },
});

// ANTI-PATTERN: include everything — fetches all columns of related rows
// BAD: const post = await prisma.post.findUnique({ where: { id }, include: { author: true, tags: true, comments: { include: { author: true } } } });
// This causes N+1-style data over-fetching. Use select to scope exactly what you need.
```

### Prisma Transactions

```typescript
// Sequential transactions ($transaction with array)
// Runs in order, rolls back all if any throws
const [order, _item, _inventory] = await prisma.$transaction([
  prisma.order.create({ data: { userId: 'u1', total: 99.99 } }),
  prisma.orderItem.create({ data: { orderId: 'o1', productId: 'p1', quantity: 1, price: 99.99 } }),
  prisma.product.update({ where: { id: 'p1' }, data: { stock: { decrement: 1 } } }),
]);

// Interactive transactions (callback form) — required for conditional logic
const result = await prisma.$transaction(async (tx) => {
  const product = await tx.product.findUnique({ where: { id: 'p1' } });

  if (!product || product.stock < 1) {
    throw new Error('Out of stock');
  }

  const order = await tx.order.create({
    data: { userId: 'u1', total: product.price },
  });

  await tx.orderItem.create({
    data: { orderId: order.id, productId: product.id, quantity: 1, price: product.price },
  });

  await tx.product.update({
    where: { id: product.id },
    data: { stock: { decrement: 1 } },
  });

  return order;
}, {
  maxWait: 5000,   // ms to acquire transaction slot
  timeout: 10000,  // ms before transaction is aborted
  isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
});
```

### When to Drop to Raw SQL

Use `prisma.$queryRaw` or `prisma.$executeRaw` for:
- Complex JOINs across 3+ tables with aggregations
- CTEs and window functions
- UPSERT with complex conflict resolution
- Bulk operations needing RETURNING *
- Database-specific functions (pg_trgm, postgis, etc.)

```typescript
import { Prisma } from '@prisma/client';

// $queryRaw returns typed results (use Prisma.sql for parameterization)
const results = await prisma.$queryRaw<{ userId: string; total: number }[]>(
  Prisma.sql`
    SELECT u.id AS "userId", SUM(o.total)::float AS total
    FROM users u
    JOIN orders o ON o.user_id = u.id
    WHERE o.created_at > ${new Date('2025-01-01')}
      AND o.status = 'DELIVERED'
    GROUP BY u.id
    HAVING SUM(o.total) > ${1000}
    ORDER BY total DESC
    LIMIT ${20}
  `
);

// $executeRaw for DDL-like or no-return statements
await prisma.$executeRaw`
  UPDATE products SET search_vector = to_tsvector('english', name || ' ' || description)
  WHERE search_vector IS NULL
`;

// NEVER use string interpolation — always use Prisma.sql or tagged template
// BAD: prisma.$queryRaw(`SELECT * FROM users WHERE id = '${userId}'`)
// GOOD: prisma.$queryRaw(Prisma.sql`SELECT * FROM users WHERE id = ${userId}`)
```

### Prisma Migrate Workflow

```bash
# Development: auto-generate migration from schema diff
npx prisma migrate dev --name add_user_profile

# This command:
# 1. Detects schema changes
# 2. Generates SQL migration file in prisma/migrations/
# 3. Applies it to dev database
# 4. Regenerates Prisma Client

# Production: apply pending migrations (no schema changes)
npx prisma migrate deploy

# Reset dev database (destructive — dev only)
npx prisma migrate reset

# Check migration status
npx prisma migrate status

# Pull existing DB schema into schema.prisma (reverse-engineering)
npx prisma db pull

# Push schema directly without migration files (prototyping only)
npx prisma db push
```

---

## Drizzle ORM (SQL-Like, TypeScript)

### Schema Definition

```typescript
// db/schema.ts
import {
  pgTable, varchar, text, boolean, timestamp,
  integer, decimal, pgEnum, index, uniqueIndex
} from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

export const orderStatusEnum = pgEnum('order_status', [
  'PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED'
]);

export const users = pgTable('users', {
  id: varchar('id', { length: 25 }).primaryKey().$defaultFn(() => createId()),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 255 }).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull().$onUpdateFn(() => new Date()),
  deletedAt: timestamp('deleted_at'),
}, (table) => ({
  emailIdx: index('users_email_idx').on(table.email),
  createdAtIdx: index('users_created_at_idx').on(table.createdAt),
}));

export const posts = pgTable('posts', {
  id: varchar('id', { length: 25 }).primaryKey().$defaultFn(() => createId()),
  title: varchar('title', { length: 255 }).notNull(),
  content: text('content'),
  published: boolean('published').default(false).notNull(),
  authorId: varchar('author_id', { length: 25 }).notNull().references(() => users.id, { onDelete: 'cascade' }),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => ({
  authorIdx: index('posts_author_idx').on(table.authorId),
}));

// Relations (for type-safe queries)
export const usersRelations = relations(users, ({ many, one }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, { fields: [posts.authorId], references: [users.id] }),
}));
```

### Query Builder Syntax

```typescript
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import { eq, and, or, gt, lt, gte, lte, like, isNull, isNotNull, inArray, desc, asc, count, sum } from 'drizzle-orm';
import * as schema from './schema';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const db = drizzle(pool, { schema });

// SELECT with conditions
const activeUsers = await db
  .select({ id: schema.users.id, email: schema.users.email, name: schema.users.name })
  .from(schema.users)
  .where(and(isNull(schema.users.deletedAt), like(schema.users.email, '%@company.com')))
  .orderBy(desc(schema.users.createdAt))
  .limit(20)
  .offset(0);

// JOIN
const postsWithAuthors = await db
  .select({
    postId: schema.posts.id,
    title: schema.posts.title,
    authorName: schema.users.name,
  })
  .from(schema.posts)
  .innerJoin(schema.users, eq(schema.posts.authorId, schema.users.id))
  .where(eq(schema.posts.published, true));

// Relational query (type-safe, uses relations config)
const usersWithPosts = await db.query.users.findMany({
  where: isNull(schema.users.deletedAt),
  with: {
    posts: {
      where: eq(schema.posts.published, true),
      orderBy: desc(schema.posts.createdAt),
      limit: 5,
    },
  },
});

// INSERT
const [newUser] = await db.insert(schema.users).values({
  email: 'alice@example.com',
  name: 'Alice',
}).returning();

// UPDATE
const [updated] = await db
  .update(schema.users)
  .set({ name: 'Alice Smith', updatedAt: new Date() })
  .where(eq(schema.users.id, 'abc123'))
  .returning();

// DELETE
await db.delete(schema.users).where(eq(schema.users.id, 'abc123'));

// Aggregation
const stats = await db
  .select({
    total: count(),
    revenue: sum(schema.orders.total),
  })
  .from(schema.orders)
  .where(eq(schema.orders.status, 'DELIVERED'));
```

### Raw SQL Escape Hatch

```typescript
import { sql } from 'drizzle-orm';

// sql tag for raw expressions in queries
const results = await db
  .select({
    id: schema.users.id,
    postCount: sql<number>`count(${schema.posts.id})::int`,
  })
  .from(schema.users)
  .leftJoin(schema.posts, eq(schema.posts.authorId, schema.users.id))
  .groupBy(schema.users.id)
  .having(sql`count(${schema.posts.id}) > 5`);

// Full raw query
const rawResults = await db.execute(
  sql`
    SELECT u.id, u.name, SUM(o.total) AS lifetime_value
    FROM users u
    JOIN orders o ON o.user_id = u.id
    WHERE o.status = 'DELIVERED'
    GROUP BY u.id, u.name
    HAVING SUM(o.total) > ${5000}
    ORDER BY lifetime_value DESC
  `
);
```

---

## SQLAlchemy (Python)

### Core vs ORM Layer

```python
from sqlalchemy import create_engine, text, Column, String, DateTime, Boolean, Numeric
from sqlalchemy.orm import DeclarativeBase, Session, relationship, sessionmaker, selectinload
from sqlalchemy.pool import QueuePool
import os

# Engine setup with connection pooling
engine = create_engine(
    os.environ['DATABASE_URL'],
    poolclass=QueuePool,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,        # test connections before use
    pool_recycle=3600,         # recycle connections after 1 hour
    echo=False,                # set True for SQL logging in dev
)

SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
```

**Use Core (lower-level) when:**
- Bulk inserts/updates where ORM overhead matters
- Raw SQL or complex expressions
- You don't need Python objects — just data

**Use ORM when:**
- Object identity matters (same row = same Python object in session)
- Business logic on model instances
- Relationship traversal and lazy loading

### ORM Model Definition

```python
from datetime import datetime, UTC
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Numeric, Integer, Enum as SAEnum
from sqlalchemy.orm import DeclarativeBase, relationship, mapped_column, Mapped
from sqlalchemy.sql import func
import enum

class Base(DeclarativeBase):
    pass

class OrderStatus(enum.Enum):
    PENDING = 'pending'
    CONFIRMED = 'confirmed'
    SHIPPED = 'shipped'
    DELIVERED = 'delivered'
    CANCELLED = 'cancelled'

class User(Base):
    __tablename__ = 'users'

    id: Mapped[str] = mapped_column(String(25), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    posts: Mapped[list['Post']] = relationship('Post', back_populates='author', lazy='select')
    orders: Mapped[list['Order']] = relationship('Order', back_populates='user')

class Post(Base):
    __tablename__ = 'posts'

    id: Mapped[str] = mapped_column(String(25), primary_key=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    content: Mapped[str | None] = mapped_column(nullable=True)
    published: Mapped[bool] = mapped_column(Boolean, default=False)
    author_id: Mapped[str] = mapped_column(String(25), ForeignKey('users.id', ondelete='CASCADE'), index=True)

    author: Mapped['User'] = relationship('User', back_populates='posts')
```

### Session Management

```python
from contextlib import contextmanager
from sqlalchemy.orm import Session

@contextmanager
def get_db():
    """Context manager for database sessions."""
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

# FastAPI dependency pattern
def get_db_dep():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Usage
with get_db() as db:
    user = db.get(User, user_id)
    user.name = 'Alice Updated'
    # commit happens automatically on __exit__
```

### Relationship Loading Strategies

```python
from sqlalchemy.orm import selectinload, joinedload, lazyload, noload
from sqlalchemy import select

# lazy (default): SELECT fired when .posts is first accessed
# BAD for loops — causes N+1
user = db.get(User, user_id)
for post in user.posts:  # triggers SELECT each time in a loop
    print(post.title)

# joinedload: single LEFT OUTER JOIN query
# Good for one-to-one, many-to-one (to-one relations)
stmt = select(Post).options(joinedload(Post.author)).where(Post.published == True)
posts = db.execute(stmt).scalars().unique().all()

# selectinload: 2 queries (SELECT users, then SELECT posts WHERE user_id IN (...))
# Best for one-to-many — avoids cartesian product
stmt = (
    select(User)
    .options(selectinload(User.posts).selectinload(Post.tags))
    .where(User.deleted_at.is_(None))
)
users = db.execute(stmt).scalars().all()

# noload: explicitly suppress loading a relation (use when you know you won't touch it)
stmt = select(User).options(noload(User.orders))
```

### Bulk Operations (Core Layer)

```python
from sqlalchemy import insert, update, delete

# Bulk insert (much faster than ORM create in loop)
db.execute(
    insert(User),
    [
        {'id': 'u1', 'email': 'a@b.com', 'name': 'Alice'},
        {'id': 'u2', 'email': 'b@b.com', 'name': 'Bob'},
    ]
)
db.commit()

# Bulk update
db.execute(
    update(User)
    .where(User.deleted_at.isnot(None))
    .values(name='[deleted]')
)
db.commit()
```

---

## Repository Pattern (Framework-Agnostic)

The repository pattern decouples data access from business logic. Services call repository methods without knowing the underlying DB technology.

### Interface Definition

```typescript
// repositories/interfaces.ts
export interface Repository<T, ID = string> {
  findById(id: ID): Promise<T | null>;
  findAll(options?: QueryOptions): Promise<T[]>;
  count(filter?: Partial<T>): Promise<number>;
  create(data: Omit<T, 'id' | 'createdAt' | 'updatedAt'>): Promise<T>;
  update(id: ID, data: Partial<T>): Promise<T | null>;
  delete(id: ID): Promise<boolean>;
}

export interface UserRepository extends Repository<User> {
  findByEmail(email: string): Promise<User | null>;
  findActiveUsers(limit: number, cursor?: string): Promise<User[]>;
}

export interface QueryOptions {
  limit?: number;
  offset?: number;
  cursor?: string;
  orderBy?: string;
  orderDir?: 'asc' | 'desc';
}
```

### Prisma Implementation

```typescript
// repositories/prisma-user.repository.ts
import { PrismaClient } from '@prisma/client';
import { UserRepository, QueryOptions } from './interfaces';
import { User } from '../types';

export class PrismaUserRepository implements UserRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async findAll(options: QueryOptions = {}): Promise<User[]> {
    const { limit = 20, offset = 0, orderBy = 'createdAt', orderDir = 'desc' } = options;
    return this.prisma.user.findMany({
      where: { deletedAt: null },
      take: limit,
      skip: offset,
      orderBy: { [orderBy]: orderDir },
    });
  }

  async findActiveUsers(limit: number, cursor?: string): Promise<User[]> {
    return this.prisma.user.findMany({
      where: { deletedAt: null },
      take: limit,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      orderBy: { createdAt: 'desc' },
    });
  }

  async count(filter?: Partial<User>): Promise<number> {
    return this.prisma.user.count({ where: { deletedAt: null, ...filter } });
  }

  async create(data: Omit<User, 'id' | 'createdAt' | 'updatedAt'>): Promise<User> {
    return this.prisma.user.create({ data });
  }

  async update(id: string, data: Partial<User>): Promise<User | null> {
    try {
      return await this.prisma.user.update({ where: { id }, data });
    } catch (e: any) {
      if (e.code === 'P2025') return null; // Record not found
      throw e;
    }
  }

  async delete(id: string): Promise<boolean> {
    try {
      await this.prisma.user.delete({ where: { id } });
      return true;
    } catch (e: any) {
      if (e.code === 'P2025') return false;
      throw e;
    }
  }
}
```

### DI Integration

```typescript
// container.ts
import { PrismaClient } from '@prisma/client';
import { PrismaUserRepository } from './repositories/prisma-user.repository';
import { UserService } from './services/user.service';

const prisma = new PrismaClient();
const userRepository = new PrismaUserRepository(prisma);
const userService = new UserService(userRepository);

export { prisma, userRepository, userService };
```

---

## ORM Anti-Patterns

### SELECT * in ORM Queries

```typescript
// BAD: loads every column including large text/blob fields
const users = await prisma.user.findMany();

// GOOD: explicit select
const users = await prisma.user.findMany({
  select: { id: true, email: true, name: true, createdAt: true },
});
```

### Over-Eager Loading Causing N+1

```typescript
// BAD: for each user, a separate query fires for orders
const users = await prisma.user.findMany();
for (const user of users) {
  const orders = await prisma.order.findMany({ where: { userId: user.id } });
  // This is N+1 — 1 users query + N order queries
}

// GOOD: single query with include
const users = await prisma.user.findMany({
  include: {
    orders: { where: { status: 'DELIVERED' }, orderBy: { createdAt: 'desc' }, take: 5 },
  },
});

// GOOD for SQLAlchemy: selectinload
stmt = select(User).options(selectinload(User.orders))
users = db.execute(stmt).scalars().all()
```

### Using ORM for Complex Aggregations

```typescript
// BAD: loading thousands of records to aggregate in JavaScript
const allOrders = await prisma.order.findMany({ where: { userId } });
const total = allOrders.reduce((sum, o) => sum + Number(o.total), 0);

// GOOD: push aggregation to the database
const { _sum } = await prisma.order.aggregate({
  where: { userId, status: 'DELIVERED' },
  _sum: { total: true },
});
const total = Number(_sum.total) || 0;

// GOOD for complex aggregations: raw SQL
const result = await prisma.$queryRaw<{ total: number }[]>`
  SELECT SUM(total)::float AS total FROM orders
  WHERE user_id = ${userId} AND status = 'DELIVERED'
`;
```

### Nested Write Cascades in Loops

```typescript
// BAD: one transaction per iteration
for (const item of items) {
  await prisma.orderItem.create({ data: { ...item } });
}

// GOOD: single createMany
await prisma.orderItem.createMany({
  data: items.map(item => ({ ...item, orderId })),
});
```
