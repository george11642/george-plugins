---
name: python-dev
description: Use when writing Python code, scripts, CLIs, APIs, libraries, or modules. Triggers python, pytest, mypy, pyright, ruff, pydantic, fastapi, flask, django, uv, pip, venv, virtualenv, asyncio, aiohttp, typing, type hints, type checking, dataclass, packaging, pyproject.toml, setuptools, hatchling, profiling, cProfile, debugging, pdb, breakpoint, linting, formatting, black, isort, pdf, pypdf, pdfplumber, reportlab, xlsx, openpyxl, docx, python-docx, pandoc, mcp, fastmcp, model context protocol, OCR, pytesseract, batch processing, file automation, spreadsheet, Word document, Django, FastAPI, Flask, SQLAlchemy, Alembic, Click, Typer, argparse, Pandas, Polars, NumPy, multiprocessing, ThreadPoolExecutor, ProcessPoolExecutor, TaskGroup, concurrent.futures, asyncpg, ORM, migrations, data validation, pandera, Great Expectations, CLI tool, command line interface, subcommands.
---

# Python Development

Master skill for Python: testing, packaging, async, performance, types, linting, debugging, file processing, and MCP server development. Philosophy: type-safe, tested, profiled-before-optimized code that uses modern tooling (uv, ruff, pyright) over legacy (pip, flake8, pylint).

## Task Router

| Task | Reference |
|------|-----------|
| Tests, fixtures, mocking, coverage | [references/testing.md](references/testing.md) |
| Packaging, pyproject.toml, publishing | [references/packaging.md](references/packaging.md) |
| Async, concurrency, event loops | [references/async.md](references/async.md) |
| uv, dependency management, lockfiles | [references/uv.md](references/uv.md) |
| Profiling, memory, CPU optimization | [references/performance.md](references/performance.md) |
| Types, Pydantic, mypy/pyright config | [references/types.md](references/types.md) |
| Linting (ruff), formatting, CI checks | [references/linting.md](references/linting.md) |
| PDF, Excel, Word / DOCX file automation | [references/file-processing.md](references/file-processing.md) |
| MCP servers, FastMCP, tool registration | [references/mcp-servers.md](references/mcp-servers.md) |
| FastAPI, Django, Flask web frameworks | [references/frameworks.md](references/frameworks.md) |
| SQLAlchemy ORM, async DB, Alembic migrations | [references/database-orm.md](references/database-orm.md) |
| asyncio TaskGroup, threading, multiprocessing | [references/concurrency-decisions.md](references/concurrency-decisions.md) |
| Pandas, Polars, NumPy, data validation | [references/data-processing.md](references/data-processing.md) |
| Click, Typer, argparse CLI tools | [references/cli-development.md](references/cli-development.md) |

## Quick Reference

### Script Starter

```python
#!/usr/bin/env python3
"""One-line description of what this script does."""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

log = logging.getLogger(__name__)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input file path")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)
    # ... logic here ...
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Why `from __future__ import annotations`: defers type evaluation, enables `X | Y` union syntax on 3.9+, avoids forward-reference strings.

### Common Patterns

| Need | Pattern |
|------|---------|
| Union type | `str \| None` (with `__future__` annotations) |
| Dataclass | `@dataclass(frozen=True, slots=True)` -- immutable + memory efficient |
| Enum | `class Color(StrEnum):` (3.11+) or `class Color(str, Enum):` |
| Context manager | `@contextmanager` + `yield` from `contextlib` |
| Temp files | `with tempfile.TemporaryDirectory() as d:` |
| Path ops | `Path("a") / "b" / "c.txt"` -- never `os.path.join` |
| Dict merge | `{**a, **b}` or `a \| b` (3.9+) |
| Env vars | `os.environ["KEY"]` (crash if missing) or `.get("KEY", default)` |
| CLI tool | `click` for complex CLIs, `argparse` for stdlib-only |
| HTTP client | `httpx` (async-native) over `requests` |

### Testing Quick Hits

```python
# Fixture with teardown
@pytest.fixture
def db():
    conn = connect()
    yield conn
    conn.close()

# Parametrize for edge cases
@pytest.mark.parametrize("input,expected", [("a", 1), ("", 0)])
def test_length(input, expected):
    assert len(input) == expected

# Mock at import boundary
with patch("myapp.services.requests.get") as mock:
    mock.return_value.json.return_value = {"id": 1}
```

## Types and Validation

Prefer static type checking -- it catches bugs before tests run.

- **Type checker**: pyright (faster, stricter) or mypy (wider ecosystem). Configure in `pyproject.toml`
- **Runtime validation**: Pydantic v2 for API boundaries, config, and data parsing
- **Dataclasses**: for internal data structures that don't need validation
- **Key rule**: annotate every function signature. Avoid `Any` unless wrapping truly dynamic APIs

```python
# Pydantic v2 model
from pydantic import BaseModel, Field, field_validator

class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: str
    age: int = Field(ge=0, le=150)

    @field_validator("email")
    @classmethod
    def must_be_valid_email(cls, v: str) -> str:
        if "@" not in v:
            raise ValueError("invalid email")
        return v.lower()
```

See [references/types.md](references/types.md) for pyright/mypy config, generics, protocols, and TypeVar patterns.

## Linting and Formatting

Use **ruff** -- it replaces flake8, isort, pyflakes, pycodestyle, and most pylint checks in one fast tool.

```toml
# pyproject.toml
[tool.ruff]
target-version = "py311"
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "W", "I", "UP", "B", "SIM", "RUF"]
# E=pycodestyle, F=pyflakes, I=isort, UP=pyupgrade, B=bugbear, SIM=simplify

[tool.ruff.format]
quote-style = "double"
```

Why ruff over flake8+isort+black: 10-100x faster, single config, auto-fixes most issues. Run `ruff check --fix . && ruff format .`

See [references/linting.md](references/linting.md) for rule selection, per-file ignores, and CI setup.

## Debugging

- **`breakpoint()`** (3.7+) drops into pdb. Set `PYTHONBREAKPOINT=0` to disable in prod
- **`python -m pdb script.py`** for post-mortem on crash
- **pdb commands**: `n`(ext), `s`(tep into), `c`(ontinue), `p expr`, `pp obj`, `l`(ist), `w`(here), `u`(p), `d`(own)
- **`debugpy`** for remote/VSCode debugging: `python -m debugpy --listen 5678 --wait-for-client script.py`
- **`icecream`** for quick print-debugging: `from icecream import ic; ic(variable)` -- shows expression + value
- **`traceback.print_exc()`** in except blocks for full stack traces without re-raising

Why `breakpoint()` over `import pdb; pdb.set_trace()`: one call, configurable via env var, works with any debugger.

## Core Principles

1. **Profile before optimizing** -- cProfile/py-spy first, then fix the hot path (see references/performance.md)
2. **Test at boundaries** -- mock external APIs, test business logic directly
3. **Use uv, not pip** -- 10-100x faster, proper lockfiles, reproducible envs (see references/uv.md)
4. **src layout** -- `src/my_package/` prevents accidental imports of uninstalled code
5. **Type everything** -- gradual typing is fine, but new code gets full annotations
6. **One formatter, one linter** -- ruff handles both. No flake8+isort+black frankenstack
7. **Async when I/O-bound** -- asyncio for network/disk, multiprocessing for CPU (see references/async.md)
8. **Explicit over implicit** -- no star imports, no mutable default args, no bare excepts
