# Database and ORM Reference

## SQLAlchemy 2.0+

SQLAlchemy 2.0 is the standard — it removed legacy patterns (Query API, `Column()` without type hints) and unified the ORM and Core APIs around `select()` statements and `Mapped` type annotations.

### Declarative Models with Type Hints

```python
from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy import ForeignKey, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "user"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    bio: Mapped[Optional[str]]                      # nullable = Optional
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    posts: Mapped[List[Post]] = relationship(back_populates="author")


class Post(Base):
    __tablename__ = "post"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(255))
    body: Mapped[str]
    author_id: Mapped[int] = mapped_column(ForeignKey("user.id"))

    author: Mapped[User] = relationship(back_populates="posts")
    tags: Mapped[List[Tag]] = relationship(secondary="post_tag", back_populates="posts")
```

### Many-to-Many with Association Table

```python
from sqlalchemy import Table, Column

# Association table (no ORM class needed for simple join tables)
post_tag = Table(
    "post_tag",
    Base.metadata,
    Column("post_id", ForeignKey("post.id"), primary_key=True),
    Column("tag_id", ForeignKey("tag.id"), primary_key=True),
)

class Tag(Base):
    __tablename__ = "tag"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True)

    posts: Mapped[List[Post]] = relationship(secondary="post_tag", back_populates="tags")
```

### Sync Session (Basic Usage)

```python
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

engine = create_engine(
    "postgresql+psycopg2://user:pass@localhost/db",
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,   # validate connections before use
    pool_recycle=3600,    # recycle connections every hour
)

# Context manager handles commit/rollback
with Session(engine) as session:
    # Insert
    user = User(name="Alice", email="alice@example.com")
    session.add(user)
    session.flush()     # sends INSERT, assigns id, stays in transaction
    session.commit()    # commits transaction

    # Query
    stmt = select(User).where(User.email == "alice@example.com")
    user = session.scalars(stmt).one()

    # Update
    user.name = "Alice Smith"
    session.commit()

    # Delete
    session.delete(user)
    session.commit()
```

### Async SQLAlchemy (asyncpg for PostgreSQL)

Install: `pip install sqlalchemy[asyncio] asyncpg`

```python
from sqlalchemy.ext.asyncio import (
    AsyncAttrs,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

# AsyncAttrs enables awaitable lazy-loaded attributes
class Base(AsyncAttrs, DeclarativeBase):
    pass

# Single engine per process — create once at startup
engine = create_async_engine(
    "postgresql+asyncpg://user:pass@localhost/db",
    pool_size=20,
    max_overflow=0,      # no overflow for async — use pool_size appropriately
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=False,          # set True for SQL logging in dev
)

# Single sessionmaker per process
async_session = async_sessionmaker(engine, expire_on_commit=False)
# expire_on_commit=False: attributes stay accessible after commit (important for async)
```

### FastAPI Dependency Pattern (Async)

```python
from collections.abc import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

# In route
@app.get("/users/{user_id}")
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404)
    return user
```

### Async Queries

```python
from sqlalchemy import select

async def get_user_with_posts(db: AsyncSession, user_id: int) -> User:
    # selectinload: separate SELECT IN query (preferred for async)
    stmt = (
        select(User)
        .where(User.id == user_id)
        .options(selectinload(User.posts))
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()

# Streaming large result sets
async def stream_all_users(db: AsyncSession):
    stmt = select(User).order_by(User.id)
    async for user in await db.stream_scalars(stmt):
        yield user
```

### Eager Loading vs Lazy Loading

```python
from sqlalchemy.orm import selectinload, joinedload, lazyload, noload

# joinedload: single JOIN query (best for one-to-one, many-to-one)
stmt = select(Post).options(joinedload(Post.author))

# selectinload: separate SELECT IN query (best for one-to-many in async)
stmt = select(User).options(selectinload(User.posts))

# noload: don't load relationship at all
stmt = select(User).options(noload(User.posts))

# RULE: In async context, always use selectinload or joinedload.
# Lazy loading (.posts) will raise MissingGreenlet error in async.
```

N+1 Detection: if you see N+1 queries in logs (`echo=True`), add `selectinload`/`joinedload` to the query.

### Connection Pool Configuration

| Parameter | Sync (psycopg2) | Async (asyncpg) |
|-----------|-----------------|-----------------|
| `pool_size` | 5–20 | 5–20 |
| `max_overflow` | 10–20 | 0 (recommended) |
| `pool_pre_ping` | True | True |
| `pool_recycle` | 3600 | 3600 |

Async `max_overflow=0`: asyncpg is fast enough that you rarely need overflow. Better to queue than create too many connections.

### Transaction Patterns

```python
# Automatic transaction (commit on success, rollback on exception)
async with async_session() as session:
    async with session.begin():
        session.add(user)
        # auto-commit on __aexit__, auto-rollback on exception

# Nested transactions (savepoints)
async with session.begin():
    await session.execute(...)
    async with session.begin_nested():  # SAVEPOINT
        await session.execute(...)
        # rollback to savepoint without rolling back outer transaction

# Explicit control
session = async_session()
try:
    session.add(user)
    await session.commit()
except Exception:
    await session.rollback()
    raise
finally:
    await session.close()
```

### Raw SQL with text()

```python
from sqlalchemy import text

# When ORM is too slow or you need complex SQL
result = await db.execute(
    text("SELECT id, name FROM user WHERE email = :email"),
    {"email": "alice@example.com"}
)
row = result.fetchone()

# Mix ORM and Core
from sqlalchemy import update
stmt = (
    update(User)
    .where(User.active == False)
    .values(deleted_at=func.now())
    .returning(User.id)
)
result = await db.execute(stmt)
deleted_ids = result.scalars().all()
```

---

## Alembic Migrations

Install: `pip install alembic`

### Setup

```bash
alembic init alembic          # creates alembic/ dir and alembic.ini
```

```python
# alembic/env.py — key config
from myapp.models import Base  # import your Base to get metadata

target_metadata = Base.metadata  # enables autogenerate

# For async (asyncpg):
from sqlalchemy.ext.asyncio import create_async_engine
from alembic import context
import asyncio

def run_migrations_online():
    connectable = create_async_engine(config.get_main_option("sqlalchemy.url"))

    async def run():
        async with connectable.connect() as connection:
            await connection.run_sync(context.run_migrations)

    asyncio.run(run())
```

### Common Commands

```bash
alembic revision --autogenerate -m "add user table"   # generate from model diff
alembic upgrade head                                   # apply all pending migrations
alembic downgrade -1                                   # revert last migration
alembic current                                        # show current revision
alembic history                                        # show migration history
alembic show <rev>                                     # show migration details
```

### Migration File Structure

```python
# alembic/versions/001_add_user_table.py
from alembic import op
import sqlalchemy as sa

def upgrade() -> None:
    op.create_table(
        "user",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )
    op.create_index("ix_user_email", "user", ["email"])

def downgrade() -> None:
    op.drop_index("ix_user_email", "user")
    op.drop_table("user")
```

### Gotchas

- **Always review autogenerated migrations** — Alembic can miss: index renames, constraint name changes, custom types
- **Never edit existing migrations** once applied to production — create a new migration
- **Stamp existing DB**: `alembic stamp head` if you created tables manually
- **Data migrations**: use `op.execute()` or bulk_insert_mappings, not ORM sessions
