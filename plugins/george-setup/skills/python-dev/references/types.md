# Python Type System

## Why Type Check?

Static type checking catches entire categories of bugs (None access, wrong argument types, missing returns) without running code. It also serves as living documentation and enables better IDE support.

## Pyright Configuration (pyproject.toml)

```toml
[tool.pyright]
pythonVersion = "3.11"
typeCheckingMode = "standard"      # "off" | "basic" | "standard" | "strict"
reportMissingImports = true
reportMissingTypeStubs = "warning"
reportUnusedImport = true
reportUnusedVariable = true
venvPath = "."
venv = ".venv"
```

Start with `"basic"` on legacy codebases, use `"standard"` for new projects, `"strict"` for libraries.

## Mypy Configuration (pyproject.toml)

```toml
[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

# Per-module overrides for gradual adoption
[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false

[[tool.mypy.overrides]]
module = "third_party_lib.*"
ignore_missing_imports = true
```

## Essential Type Patterns

### Basic Annotations

```python
from __future__ import annotations
from typing import Any
from collections.abc import Sequence, Mapping, Iterator, Callable

def greet(name: str, excited: bool = False) -> str:
    return f"Hello, {name}{'!' if excited else '.'}"

def process(items: list[str]) -> dict[str, int]:
    return {item: len(item) for item in items}

# Use collections.abc for read-only params (more permissive)
def first(items: Sequence[str]) -> str | None:
    return items[0] if items else None
```

### Generics and TypeVar

```python
from typing import TypeVar

T = TypeVar("T")

def first_or_default(items: list[T], default: T) -> T:
    return items[0] if items else default

# Bounded TypeVar
from typing import SupportsFloat
N = TypeVar("N", bound=SupportsFloat)

def double(x: N) -> N:
    return x * 2  # type: ignore[return-value]
```

### Protocols (Structural Typing)

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class Drawable(Protocol):
    def draw(self, x: int, y: int) -> None: ...

# Any class with a draw(int, int) -> None method satisfies this
def render(obj: Drawable) -> None:
    obj.draw(0, 0)
```

Why protocols over ABC: no inheritance required. If it quacks like a duck, the type checker accepts it.

### TypedDict

```python
from typing import TypedDict, NotRequired

class UserDict(TypedDict):
    id: int
    name: str
    email: NotRequired[str]  # optional key

def get_user(uid: int) -> UserDict:
    return {"id": uid, "name": "Alice"}
```

### Literal and Union

```python
from typing import Literal

def set_mode(mode: Literal["read", "write", "append"]) -> None: ...

# Discriminated unions
from dataclasses import dataclass

@dataclass
class Success:
    value: str

@dataclass
class Error:
    message: str

Result = Success | Error

def handle(result: Result) -> str:
    match result:
        case Success(value=v): return v
        case Error(message=m): return f"Error: {m}"
```

### Callable Types

```python
from collections.abc import Callable

# Function that takes a string and returns int
Parser = Callable[[str], int]

def apply(fn: Parser, data: str) -> int:
    return fn(data)

# With ParamSpec for decorators that preserve signatures
from typing import ParamSpec, TypeVar
P = ParamSpec("P")
R = TypeVar("R")

def log_calls(fn: Callable[P, R]) -> Callable[P, R]:
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        print(f"Calling {fn.__name__}")
        return fn(*args, **kwargs)
    return wrapper
```

## Pydantic v2 Patterns

### Model Configuration

```python
from pydantic import BaseModel, Field, field_validator, model_validator, ConfigDict

class Config(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
        frozen=True,              # immutable after creation
        extra="forbid",           # no extra fields allowed
    )

    host: str = Field(default="localhost")
    port: int = Field(default=8080, ge=1, le=65535)
    tags: list[str] = Field(default_factory=list)

    @field_validator("host")
    @classmethod
    def validate_host(cls, v: str) -> str:
        if not v:
            raise ValueError("host cannot be empty")
        return v

    @model_validator(mode="after")
    def check_consistency(self) -> "Config":
        # cross-field validation
        return self
```

### Serialization

```python
data = config.model_dump()                    # -> dict
json_str = config.model_dump_json(indent=2)   # -> JSON string
config2 = Config.model_validate(data)          # dict -> model
config3 = Config.model_validate_json(raw)      # JSON -> model
```

### Common Pydantic v2 Gotchas

- Use `model_config = ConfigDict(...)` not nested `class Config`
- Use `field_validator` not deprecated `validator`
- Use `model_dump()` not deprecated `.dict()`
- Validators need `@classmethod` decorator
- `Field(default_factory=list)` not `Field(default=[])`

## Gradual Typing Strategy

1. Start with function signatures on new code
2. Add `# type: ignore[code]` for legacy code (with specific error code)
3. Enable stricter settings per-module as coverage grows
4. Use `reveal_type(expr)` during development to inspect inferred types
5. Run type checker in CI to prevent regressions
