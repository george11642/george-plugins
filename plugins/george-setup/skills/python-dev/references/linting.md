# Python Linting and Formatting with Ruff

## Why Ruff?

Ruff replaces flake8, isort, pyflakes, pycodestyle, pydocstyle, pyupgrade, autoflake, and most pylint checks. It's written in Rust and runs 10-100x faster than the tools it replaces. One config, one tool, one `pyproject.toml` section.

## Full Configuration

```toml
[tool.ruff]
target-version = "py311"
line-length = 88
src = ["src", "tests"]

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "UP",   # pyupgrade (modernize syntax)
    "B",    # flake8-bugbear (common bugs)
    "SIM",  # flake8-simplify
    "RUF",  # ruff-specific rules
    "N",    # pep8-naming
    "C4",   # flake8-comprehensions
    "PTH",  # flake8-use-pathlib
    "ERA",  # eradicate (commented-out code)
    "T20",  # flake8-print (no print statements)
]
ignore = [
    "E501",   # line too long (formatter handles this)
]

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["T20", "S101"]  # allow print + assert in tests
"__init__.py" = ["F401"]            # allow unused imports in __init__

[tool.ruff.lint.isort]
known-first-party = ["mypackage"]
force-single-line = false
combine-as-imports = true

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
docstring-code-format = true
```

## Common Rule Groups

| Code | Group | What it catches |
|------|-------|-----------------|
| E/W | pycodestyle | Style violations (whitespace, indentation) |
| F | pyflakes | Unused imports, undefined names, shadowed vars |
| I | isort | Import sorting/grouping |
| UP | pyupgrade | Old syntax (`dict()` -> `{}`, `type(x) is` -> `isinstance`) |
| B | bugbear | Common bugs (mutable defaults, bare except, assert False) |
| SIM | simplify | Simplifiable constructs (`not not x` -> `x`) |
| N | naming | PEP 8 naming (CamelCase classes, snake_case functions) |
| C4 | comprehensions | Unnecessary list/dict/set calls that could be comprehensions |
| PTH | pathlib | `os.path.*` calls that should use `pathlib.Path` |
| T20 | print | Print statements (use logging instead) |
| S | bandit | Security issues (hardcoded passwords, SQL injection) |
| ERA | eradicate | Commented-out code |

## CLI Usage

```bash
# Check for issues
ruff check .

# Check and auto-fix
ruff check --fix .

# Format code (replaces black)
ruff format .

# Check what would change without modifying
ruff check --diff .
ruff format --check .

# Check specific files/dirs
ruff check src/ tests/

# Show all available rules
ruff rule --all
```

## CI Integration

```yaml
# GitHub Actions
- name: Lint
  run: |
    pip install ruff
    ruff check --output-format=github .
    ruff format --check .
```

```bash
# Pre-commit hook (.pre-commit-config.yaml)
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

## Migration from Legacy Tools

### From flake8
- Move `select`/`ignore` from `.flake8` or `setup.cfg` to `[tool.ruff.lint]`
- Ruff uses the same E/W/F codes
- Remove `flake8` and its plugins from dependencies

### From isort
- Ruff's `I` rule replaces isort entirely
- Move `known_first_party` to `[tool.ruff.lint.isort]`
- Remove `isort` from dependencies

### From black
- `ruff format` is a drop-in replacement
- Same `line-length` setting applies
- Remove `black` from dependencies

## Common Auto-Fixes

| Before | After | Rule |
|--------|-------|------|
| `dict(a=1)` | `{"a": 1}` | UP013 |
| `"{0}".format(x)` | `f"{x}"` | UP032 |
| `type(x) == int` | `isinstance(x, int)` | E721 |
| `os.path.join(a, b)` | `Path(a) / b` | PTH118 |
| `list(x for x in y)` | `[x for x in y]` | C400 |
| `not x in y` | `x not in y` | E713 |

## Suppressing Rules

```python
x = unsafe_call()  # noqa: S307 -- justified reason here
```

Always add a comment explaining why the suppression is needed.
