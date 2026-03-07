# Web Frameworks Reference

## FastAPI (recommended for modern APIs)

FastAPI is the default choice for new Python APIs: async-native, automatic OpenAPI docs, Pydantic v2 integration, and high performance via Starlette/uvicorn.

### App Creation and Lifespan

Use `lifespan` (not deprecated `on_event`). It's an `asynccontextmanager` — code before `yield` runs at startup, after `yield` at shutdown.

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize DB pool, load ML models, connect to Redis
    app.state.db_pool = await create_db_pool()
    yield
    # Shutdown: clean up resources
    await app.state.db_pool.close()

app = FastAPI(lifespan=lifespan)
```

Why lifespan over `on_event`: single context manager is composable, testable, and the modern standard. `on_startup`/`on_shutdown` are deprecated.

### Pydantic v2 Request/Response Models

```python
from pydantic import BaseModel, Field, EmailStr

class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    age: int = Field(ge=0, le=150)

class UserResponse(BaseModel):
    id: int
    name: str
    email: str

    model_config = {"from_attributes": True}  # enables ORM mode (replaces orm_mode=True)

@app.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate, db: AsyncSession = Depends(get_db)):
    ...
```

### Dependency Injection with Depends()

FastAPI's DI system is hierarchical — dependencies can depend on other dependencies. Results are cached per request by default.

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session  # yield = cleanup runs after request

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    user = await db.get(User, decode_token(token))
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return user

# Use at route level
@app.get("/me")
async def read_me(current_user: User = Depends(get_current_user)):
    return current_user
```

**Modern Annotated style** (FastAPI 0.95+):
```python
from typing import Annotated

DbDep = Annotated[AsyncSession, Depends(get_db)]
UserDep = Annotated[User, Depends(get_current_user)]

@app.get("/me")
async def read_me(db: DbDep, user: UserDep):
    ...
```

**Singleton resources via lifespan** (not module-level globals):
```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.redis = await aioredis.from_url("redis://localhost")
    yield
    await app.state.redis.close()

async def get_redis(request: Request) -> Redis:
    return request.app.state.redis
```

**Dependency overrides for testing**:
```python
def override_get_db():
    yield test_session

app.dependency_overrides[get_db] = override_get_db
```

### Background Tasks

```python
from fastapi import BackgroundTasks

def send_email(email: str, message: str):  # runs after response is sent
    ...

@app.post("/register")
async def register(user: UserCreate, background_tasks: BackgroundTasks):
    db_user = await create_user(user)
    background_tasks.add_task(send_email, user.email, "Welcome!")
    return db_user
```

For heavier workloads use **Celery** (distributed task queue with Redis/RabbitMQ broker) or **ARQ** (async Redis Queue, simpler setup for asyncio projects).

### Middleware Patterns

```python
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
import time

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://example.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Custom middleware (logging, timing)
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    response.headers["X-Process-Time"] = str(time.perf_counter() - start)
    return response

# Auth middleware: prefer Depends() over middleware for auth —
# middleware can't return early with clean error responses as easily
```

### APIRouter for Modular Organization

```python
# routers/users.py
from fastapi import APIRouter

router = APIRouter(prefix="/users", tags=["users"])

@router.get("/")
async def list_users(): ...

@router.get("/{user_id}")
async def get_user(user_id: int): ...

# main.py
from routers import users, posts

app.include_router(users.router)
app.include_router(posts.router, dependencies=[Depends(require_auth)])
```

### Testing FastAPI

```python
# Sync client (fine for most tests)
from fastapi.testclient import TestClient

def test_create_user():
    with TestClient(app) as client:  # context manager triggers lifespan
        response = client.post("/users", json={"name": "Alice", "email": "a@b.com", "age": 30})
        assert response.status_code == 201

# Async client (when you need async fixtures)
import pytest
from httpx import AsyncClient, ASGITransport

@pytest.mark.anyio
async def test_create_user_async():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.post("/users", json={...})
        assert response.status_code == 201
```

---

## Django (batteries-included)

Use Django when you need: admin interface, ORM with migrations, auth system, forms, or a large team that knows Django conventions.

### ORM Queries

```python
# select_related: JOIN for ForeignKey/OneToOne (avoids N+1 for FK)
posts = Post.objects.select_related("author").filter(published=True)

# prefetch_related: separate query for ManyToMany/reverse FK
users = User.objects.prefetch_related("groups", "user_permissions").all()

# annotate: add computed field per row
from django.db.models import Count, Avg
posts = Post.objects.annotate(comment_count=Count("comments"))

# aggregate: single value across queryset
stats = Order.objects.aggregate(total=Sum("amount"), avg=Avg("amount"))

# Chaining querysets (lazy — no DB hit until evaluated)
qs = Post.objects.filter(published=True)
if author_id:
    qs = qs.filter(author_id=author_id)
results = list(qs.order_by("-created_at")[:20])  # DB hit here

# select_for_update: row-level lock (inside transaction)
from django.db import transaction
with transaction.atomic():
    obj = MyModel.objects.select_for_update().get(pk=pk)
    obj.balance -= amount
    obj.save()
```

### Django 4.1+ Async Views

```python
# async views work natively with ASGI (uvicorn/daphne)
from django.http import JsonResponse

async def async_view(request):
    result = await some_async_operation()
    return JsonResponse({"result": result})

# ORM in async context: use sync_to_async
from asgiref.sync import sync_to_async

@sync_to_async
def get_user(pk):
    return User.objects.select_related("profile").get(pk=pk)
```

### Signals

```python
from django.db.models.signals import post_save
from django.dispatch import receiver

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
```

### Class-Based vs Function-Based Views

```python
# FBV: explicit, easy to read, preferred for simple views
def post_list(request):
    posts = Post.objects.filter(published=True)
    return render(request, "posts/list.html", {"posts": posts})

# CBV: good for CRUD with CreateView, UpdateView, DeleteView
from django.views.generic import ListView, CreateView

class PostListView(ListView):
    model = Post
    template_name = "posts/list.html"
    queryset = Post.objects.filter(published=True)
    paginate_by = 20
```

### Custom Model Managers

```python
class PublishedManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(status="published")

class Post(models.Model):
    objects = models.Manager()       # default
    published = PublishedManager()   # custom

# Usage: Post.published.all()
```

---

## Flask (lightweight)

Use Flask for: small APIs, microservices, when you want maximum control, or when Django is overkill.

### App Factory Pattern

```python
# app/__init__.py
from flask import Flask
from .extensions import db, migrate, login_manager

def create_app(config_object="app.config.ProductionConfig"):
    app = Flask(__name__)
    app.config.from_object(config_object)

    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)

    from .blueprints.users import users_bp
    from .blueprints.api import api_bp
    app.register_blueprint(users_bp)
    app.register_blueprint(api_bp, url_prefix="/api/v1")

    return app
```

Why app factory: enables multiple app instances (testing), deferred extension initialization, avoids circular imports.

### Blueprints

```python
# blueprints/users.py
from flask import Blueprint, jsonify, request

users_bp = Blueprint("users", __name__, url_prefix="/users")

@users_bp.route("/", methods=["GET"])
def list_users():
    return jsonify([...])

@users_bp.before_request
def require_auth():
    if not current_user.is_authenticated:
        return jsonify({"error": "unauthorized"}), 401
```

### Request Hooks and Error Handlers

```python
@app.before_request
def log_request():
    g.start_time = time.perf_counter()

@app.teardown_request
def close_db(exception):
    db = g.pop("db", None)
    if db is not None:
        db.close()

@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Not found"}), 404

@app.errorhandler(Exception)
def handle_unexpected_error(error):
    logger.exception("Unhandled exception")
    return jsonify({"error": "Internal server error"}), 500
```

### Flask-SQLAlchemy Pattern

```python
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class User(db.Model):
    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(80), unique=True)

# In view
user = db.session.get(User, user_id)
db.session.add(new_user)
db.session.commit()
```
