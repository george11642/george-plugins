# uv Package Manager

## Installation

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # macOS/Linux
brew install uv                                      # Homebrew
pip install uv                                       # pip
```

## Project Lifecycle

```bash
uv init my-project          # Create project (pyproject.toml + .python-version)
cd my-project
uv python pin 3.12          # Pin Python version
uv add fastapi uvicorn      # Add dependencies
uv add --dev pytest ruff    # Add dev dependencies
uv add --optional docs sphinx  # Optional group
uv sync                     # Install everything
uv run pytest               # Run in venv (no activation needed)
uv lock                     # Create/update uv.lock
```

## Dependency Management

```bash
uv add "django>=4.0,<5.0"          # Version constraint
uv add git+https://github.com/user/repo.git@v1.0  # Git
uv add -e ./local-package          # Editable local
uv remove requests                  # Remove
uv add --upgrade requests          # Upgrade specific
uv sync --upgrade                  # Upgrade all
uv tree --outdated                 # Show outdated
```

## Virtual Environments

```bash
uv venv                     # Create .venv
uv venv --python 3.12       # Specific version
uv run python script.py     # Run without activation (preferred)
source .venv/bin/activate    # Traditional activation
```

## Python Version Management

```bash
uv python install 3.12      # Install Python
uv python install 3.11 3.12 3.13  # Multiple
uv python list              # List installed
uv python pin 3.12          # Set project version
```

## Lockfiles

```bash
uv lock                     # Create uv.lock
uv lock --upgrade           # Update all
uv lock --upgrade-package requests  # Update one
uv lock --check             # Verify up to date
uv sync --frozen            # Install exact versions (CI)
uv export --format requirements-txt > requirements.txt  # Export
```

## CI/CD (GitHub Actions)

```yaml
- uses: astral-sh/setup-uv@v2
  with: { enable-cache: true }
- run: uv python install 3.12
- run: uv sync --all-extras --dev
- run: uv run pytest
- run: uv run ruff check .
```

## Docker

```dockerfile
FROM python:3.12-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-editable

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /app/.venv .venv
COPY . .
ENV PATH="/app/.venv/bin:$PATH"
CMD ["python", "app.py"]
```

## Workspaces (Monorepo)

```toml
# Root pyproject.toml
[tool.uv.workspace]
members = ["packages/*"]
```

## Migration

```bash
# From pip
uv add -r requirements.txt

# From poetry (reads pyproject.toml)
uv sync

# From pip-tools
uv lock && uv sync --frozen
```

## pyproject.toml uv Config

```toml
[tool.uv]
dev-dependencies = []

[tool.uv.sources]
my-package = { git = "https://github.com/user/repo.git" }
```

## Cache & Troubleshooting

```bash
uv cache clean              # Clear cache
uv cache dir                # Show location
uv lock --verbose           # Debug resolution
uv python pin 3.12          # Fix wrong Python version
```

## Key Commands Reference

```bash
uv init [PATH]              # Initialize project
uv add PACKAGE              # Add dependency
uv remove PACKAGE           # Remove dependency
uv sync                     # Install deps
uv lock                     # Create/update lockfile
uv venv [PATH]              # Create venv
uv run COMMAND              # Run in venv
uv python install VERSION   # Install Python
uv python pin VERSION       # Pin version
uv pip install/freeze/list  # pip-compatible commands
```

## Best Practices

1. Always commit `uv.lock` to version control
2. Use `uv run` instead of manual venv activation
3. Use `--frozen` in CI for reproducible builds
4. Pin Python version with `.python-version`
5. Separate dev dependencies from production
6. Use workspaces for monorepos
