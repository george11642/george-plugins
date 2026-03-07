# CLI Development Reference

## Quick Comparison

| Feature | click | typer | argparse |
|---------|-------|-------|----------|
| API style | Decorators | Type annotations | Method calls |
| Subcommands | `@group` | `app.add_typer()` | `add_subparsers()` |
| Type coercion | Manual types | Automatic | Manual |
| Autocompletion | Plugin | Built-in | Manual |
| Testing | CliRunner | CliRunner | Custom |
| Dependency | `click` | `typer[all]` | stdlib |
| Best for | Complex CLIs, full control | Modern Python, fast setup | stdlib-only |

**Default recommendation**: `typer` for new projects (less boilerplate, type-safe). Use `click` when you need its ecosystem (click-extra, etc.) or fine-grained control. Use `argparse` only when zero dependencies required.

---

## Click

### Basic App with Group and Subcommands

```python
import click

@click.group()
@click.option("--verbose", "-v", is_flag=True, help="Enable verbose output")
@click.version_option(version="1.0.0")
@click.pass_context
def cli(ctx: click.Context, verbose: bool) -> None:
    """My CLI tool — does awesome things."""
    ctx.ensure_object(dict)
    ctx.obj["VERBOSE"] = verbose

@cli.command()
@click.argument("name")
@click.option("--greeting", "-g", default="Hello", help="Greeting to use")
@click.pass_context
def greet(ctx: click.Context, name: str, greeting: str) -> None:
    """Greet someone by name."""
    if ctx.obj["VERBOSE"]:
        click.echo(f"Running greet command")
    click.echo(f"{greeting}, {name}!")

@cli.command()
@click.argument("input_file", type=click.Path(exists=True, path_type=Path))
@click.option("--output", "-o", type=click.Path(path_type=Path), required=True)
def process(input_file: Path, output: Path) -> None:
    """Process a file."""
    ...

if __name__ == "__main__":
    cli()
```

### Option Types

```python
# Path type — validates existence, writable, etc.
@click.option("--config", type=click.Path(exists=True, file_okay=True, dir_okay=False, path_type=Path))

# Choice — restricts to allowed values
@click.option("--format", type=click.Choice(["json", "csv", "parquet"], case_sensitive=False))

# IntRange — bounded integer
@click.option("--workers", type=click.IntRange(1, 32), default=4)

# FloatRange
@click.option("--threshold", type=click.FloatRange(0.0, 1.0), default=0.5)

# Multiple values
@click.option("--tag", multiple=True)  # --tag foo --tag bar → tags = ("foo", "bar")

# Tuple type
@click.option("--point", nargs=2, type=float)  # --point 1.0 2.0 → point = (1.0, 2.0)

# Flag with on/off
@click.option("--debug/--no-debug", default=False)
```

### Callbacks and Eager Options

```python
def print_version(ctx, param, value):
    if not value or ctx.resilient_parsing:
        return
    click.echo("Version 1.0.0")
    ctx.exit()

@click.option("--version", is_flag=True, is_eager=True, expose_value=False,
              callback=print_version, help="Show version and exit")
```

### Context Passing with ctx.obj

```python
# Dataclass for type-safe context
from dataclasses import dataclass

@dataclass
class Config:
    verbose: bool
    api_url: str

@click.group()
@click.option("--api-url", default="https://api.example.com")
@click.option("--verbose", is_flag=True)
@click.pass_context
def cli(ctx: click.Context, api_url: str, verbose: bool) -> None:
    ctx.obj = Config(verbose=verbose, api_url=api_url)

@cli.command()
@click.pass_obj  # injects ctx.obj directly (not full ctx)
def status(config: Config) -> None:
    if config.verbose:
        click.echo(f"Checking {config.api_url}")
```

### Testing Click CLIs with CliRunner

```python
from click.testing import CliRunner
from myapp.cli import cli

def test_greet():
    runner = CliRunner()
    result = runner.invoke(cli, ["greet", "Alice"])
    assert result.exit_code == 0
    assert "Hello, Alice!" in result.output

def test_process_file(tmp_path):
    runner = CliRunner()
    input_file = tmp_path / "input.txt"
    input_file.write_text("data")

    with runner.isolated_filesystem(temp_dir=tmp_path):
        result = runner.invoke(cli, ["process", str(input_file), "--output", "out.txt"])
        assert result.exit_code == 0, result.output

def test_missing_required_arg():
    runner = CliRunner()
    result = runner.invoke(cli, ["process"])
    assert result.exit_code != 0
    assert "Missing argument" in result.output
```

### Shell Completion

```bash
# Bash
eval "$(_MY_CLI_COMPLETE=bash_source my-cli)"

# Zsh
eval "$(_MY_CLI_COMPLETE=zsh_source my-cli)"

# Fish
eval (env _MY_CLI_COMPLETE=fish_source my-cli)
```

---

## Typer (Modern Type-Hint-Driven)

### Basic App

```python
import typer
from pathlib import Path
from typing import Optional

app = typer.Typer(help="My CLI tool")

@app.command()
def greet(
    name: str = typer.Argument(..., help="Name to greet"),
    greeting: str = typer.Option("Hello", "--greeting", "-g", help="Greeting to use"),
    verbose: bool = typer.Option(False, "--verbose", "-v"),
) -> None:
    """Greet someone by name."""
    if verbose:
        typer.echo(f"Running greet")
    typer.echo(f"{greeting}, {name}!")

@app.command()
def process(
    input_file: Path = typer.Argument(..., exists=True, help="Input file"),
    output: Path = typer.Option(..., "--output", "-o", help="Output path"),
    workers: int = typer.Option(4, min=1, max=32),
) -> None:
    """Process a file."""
    ...

if __name__ == "__main__":
    app()
```

### Subcommands and Command Groups

```python
import typer

app = typer.Typer()
users_app = typer.Typer()
posts_app = typer.Typer()

app.add_typer(users_app, name="users", help="User management commands")
app.add_typer(posts_app, name="posts", help="Post management commands")

@users_app.command("list")
def list_users(active: bool = typer.Option(True, help="Show only active users")) -> None:
    """List all users."""
    ...

@users_app.command("create")
def create_user(
    name: str,
    email: str,
    admin: bool = typer.Option(False),
) -> None:
    """Create a new user."""
    ...
```

### Optional Parameters and Defaults

```python
from typing import Optional
import typer

@app.command()
def search(
    query: str,
    limit: Optional[int] = typer.Option(None, help="Max results (None = unlimited)"),
    format: str = typer.Option("json", help="Output format", case_sensitive=False),
    tags: list[str] = typer.Option([], help="Filter by tags"),
) -> None:
    ...
```

### Progress and Styling

```python
import typer
import time

@app.command()
def process_many(count: int = 100) -> None:
    with typer.progressbar(range(count), label="Processing") as progress:
        for item in progress:
            time.sleep(0.01)

    typer.echo(typer.style("Done!", fg=typer.colors.GREEN, bold=True))
```

### Autocompletion

```python
# Install completions
typer run myapp/__main__.py --install-completion  # for current shell
typer run myapp/__main__.py --show-completion     # show completion script

# Custom completion for an option
def complete_format(incomplete: str):
    formats = ["json", "csv", "parquet", "xlsx"]
    return [f for f in formats if f.startswith(incomplete)]

@app.command()
def export(
    format: str = typer.Option("json", autocompletion=complete_format),
) -> None: ...
```

### Testing Typer Apps

```python
from typer.testing import CliRunner
from myapp.cli import app

runner = CliRunner()

def test_greet():
    result = runner.invoke(app, ["greet", "Alice"])
    assert result.exit_code == 0
    assert "Hello, Alice!" in result.output
```

---

## argparse (stdlib)

Use when: zero external dependencies required, or maintaining existing code.

### Subparsers for Subcommands

```python
import argparse
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="My CLI tool")
    parser.add_argument("--verbose", "-v", action="store_true")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # greet subcommand
    greet_parser = subparsers.add_parser("greet", help="Greet someone")
    greet_parser.add_argument("name")
    greet_parser.add_argument("--greeting", default="Hello")

    # process subcommand
    process_parser = subparsers.add_parser("process", help="Process a file")
    process_parser.add_argument("input", type=Path)
    process_parser.add_argument("--output", "-o", type=Path, required=True)
    process_parser.add_argument("--workers", type=int, default=4,
                                choices=range(1, 33), metavar="1-32")

    args = parser.parse_args()

    if args.command == "greet":
        print(f"{args.greeting}, {args.name}!")
    elif args.command == "process":
        run_process(args.input, args.output, args.workers)

if __name__ == "__main__":
    main()
```

### Custom Action Classes

```python
class CommaSeparatedList(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        setattr(namespace, self.dest, values.split(","))

parser.add_argument("--tags", action=CommaSeparatedList)
# --tags foo,bar,baz → args.tags = ["foo", "bar", "baz"]
```

### Mutually Exclusive Groups

```python
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--json", action="store_true")
group.add_argument("--csv", action="store_true")
group.add_argument("--parquet", action="store_true")
```

### Type Converters

```python
def bounded_int(value, min_val=1, max_val=100):
    n = int(value)
    if not (min_val <= n <= max_val):
        raise argparse.ArgumentTypeError(f"Must be {min_val}-{max_val}")
    return n

parser.add_argument("--workers", type=lambda v: bounded_int(v, 1, 32), default=4)
```

---

## CLI Best Practices

- **Exit codes**: `sys.exit(0)` success, `sys.exit(1)` general error. Consistent codes help scripts.
- **Stderr for errors**: `click.echo("Error: ...", err=True)` / `typer.echo("Error", err=True)`
- **Machine-readable output**: support `--json` flag for scripting, human-readable by default
- **Progress to stderr**: progress bars should go to stderr so stdout stays clean for piping
- **`--dry-run`**: add to destructive commands so users can preview
- **Config file + env vars + CLI flags**: precedence should be CLI > env > config file (use `click-extra` or manual `os.environ.get` for this)
- **Always test with CliRunner**: test help text, error cases, and exit codes, not just happy path
