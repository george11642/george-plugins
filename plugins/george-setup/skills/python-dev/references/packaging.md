# Python Packaging

## Project Structure (src layout, recommended)

```
my-package/
  pyproject.toml
  README.md
  LICENSE
  src/
    my_package/
      __init__.py
      core.py
      py.typed
  tests/
    test_core.py
  docs/
```

## pyproject.toml Template

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "my-package"
version = "1.0.0"
description = "Short description"
readme = "README.md"
requires-python = ">=3.9"
license = {text = "MIT"}
authors = [{name = "Name", email = "email@example.com"}]
keywords = ["keyword1", "keyword2"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Programming Language :: Python :: 3",
]
dependencies = [
    "requests>=2.28.0,<3.0.0",
    "click>=8.0.0",
]

[project.optional-dependencies]
dev = ["pytest>=7.0", "black>=23.0", "ruff>=0.1.0", "mypy>=1.0"]
docs = ["sphinx>=5.0"]

[project.urls]
Homepage = "https://github.com/user/my-package"
Repository = "https://github.com/user/my-package"

[project.scripts]
my-cli = "my_package.cli:main"

[tool.setuptools.packages.find]
where = ["src"]

[tool.setuptools.package-data]
my_package = ["py.typed", "data/*.json"]
```

## Version Constraints

```toml
"requests>=2.28.0,<3.0.0"   # Compatible range
"click~=8.1.0"               # >=8.1.0, <8.2.0
"pydantic>=2.0"              # Minimum only
```

## Dynamic Versioning

```toml
[project]
dynamic = ["version"]

# Option 1: From __init__.py
[tool.setuptools.dynamic]
version = {attr = "my_package.__version__"}

# Option 2: Git-based (setuptools-scm)
[tool.setuptools_scm]
write_to = "src/my_package/_version.py"
```

## CLI with Click

```python
# src/my_package/cli.py
import click

@click.group()
@click.version_option()
def cli():
    """My CLI tool."""

@cli.command()
@click.argument("name")
@click.option("--greeting", default="Hello")
def greet(name, greeting):
    click.echo(f"{greeting}, {name}!")

def main():
    cli()
```

## Data Files

```python
from importlib.resources import files

data = files("my_package").joinpath("data/config.json").read_text()
```

## Build and Publish

```bash
pip install build twine
python -m build               # Creates dist/*.whl and dist/*.tar.gz
twine check dist/*            # Validate
twine upload --repository testpypi dist/*  # Test first
twine upload dist/*           # Publish to PyPI
```

## GitHub Actions

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-python@v5
  with: { python-version: "3.12" }
- run: pip install build twine
- run: python -m build
- run: twine upload dist/*
  env:
    TWINE_USERNAME: __token__
    TWINE_PASSWORD: ${{ secrets.PYPI_API_TOKEN }}
```

## Namespace Packages

No `__init__.py` in the namespace directory:
```
company/         # No __init__.py here
  core/
    __init__.py
```

## Checklist

- [ ] Tests passing, coverage adequate
- [ ] Version number updated (semantic versioning)
- [ ] pyproject.toml complete (classifiers, URLs, keywords)
- [ ] LICENSE file included
- [ ] README with install/usage instructions
- [ ] Tested in clean venv: `pip install dist/*.whl`
- [ ] Tested on TestPyPI first
- [ ] Git tag created for release
