# ShellCheck Configuration Reference

Detailed ShellCheck patterns and configuration. Parent skill: [../SKILL.md](../SKILL.md)

## Installation

```bash
brew install shellcheck       # macOS
apt-get install shellcheck    # Debian/Ubuntu
shellcheck --version          # Verify
```

## Project Configuration (.shellcheckrc)

Place in project root:

```
shell=bash
enable=avoid-nullary-conditions,require-variable-braces,check-unassigned-uppercase
disable=SC1091
external-sources=true
```

## Environment Variables

```bash
export SHELLCHECK_SHELL=bash
export SHELLCHECK_CONFIG=~/.shellcheckrc

# Enable strict mode globally (equivalent to --enable=all with no exclusions)
export SHELLCHECK_STRICT=true
```

## Useful Flags

```bash
# --check-sourced: also lint files brought in via `source` / `.`
# Catches issues in helper libraries that are sourced but not directly passed to shellcheck
shellcheck --check-sourced main.sh

# --severity: filter by minimum severity level
# Levels (lowest to highest): style, info, warning, error
shellcheck --severity=warning scripts/*.sh   # CI minimum: ignore style/info
shellcheck --severity=error   scripts/*.sh   # Strictest: errors only

# --format=diff: output auto-fixable suggestions as a unified diff
shellcheck --format=diff script.sh | patch -p1  # Apply all auto-fixes at once
```

## Common Error Codes and Fixes

### Quoting (SC2086)

```bash
# Bad:  for i in $list; do
# Good: for i in "${list[@]}"; do
```

### Exit Code (SC2181)

```bash
# Bad:  some_cmd; if [ $? -eq 0 ]; then
# Good: if some_cmd; then
```

### Conditional (SC2015)

```bash
# Bad:  [ -f "$f" ] && echo "yes" || echo "no"
# Good: if [ -f "$f" ]; then echo "yes"; else echo "no"; fi
```

### Process Grep (SC2009)

```bash
# Bad:  ps aux | grep -v grep | grep myproc
# Good: pgrep -f myproc
```

### Single Quotes (SC2016)

```bash
# Bad:  echo 'Value: $VAR'
# Good: echo "Value: $VAR"
```

### Source Following (SC1091)

```bash
# shellcheck source=./lib/helpers.sh
source helpers.sh
```

### Unquoted Array (SC2206)

```bash
# Bad:  array=( $items )
# Good: mapfile -t array <<< "$items"
# Good: IFS=' ' read -ra array <<< "$items"
```

### Unreachable Code (SC2317)

```bash
# Bad: code after unconditional exit/return
# Fix: remove dead code or restructure control flow
```

### Useless Cat (SC2002)

```bash
# Bad:  cat file | grep pattern
# Good: grep pattern file
```

### Deprecated Backticks (SC2006)

```bash
# Bad:  result=`command`
# Good: result=$(command)
```

### Parser Errors (SC1000-1099)

- SC1004: Backslash continuation issues
- SC1008: Invalid operator data
- SC1009: Mentioned parser error
- SC1036: `(` unexpected -- usually missing quotes
- SC1073: Couldn't parse this -- check syntax around line

### POSIX Compliance (SC3000-3999)

- SC3010: `[[` not POSIX -- use `case` or `[`
- SC3043: `local` undefined in strict POSIX sh
- SC3045: `read -r` not POSIX in some interpretations

## Inline Suppression

```bash
# Single line
# shellcheck disable=SC2086
for file in $var; do done

# Entire function
command_that_fails() {
    # shellcheck disable=SC2015
    [ -f "$1" ] && echo "found" || echo "not found"
}

# Source directive
# shellcheck source=./helper.sh
source helper.sh

# Top-of-file disable (applies to entire script)
#!/bin/bash
# shellcheck disable=SC2034,SC1091
```

Always document the reason for suppression:

```bash
# shellcheck disable=SC2086 -- intentional word splitting for space-separated list
for item in $SPACE_SEPARATED_ITEMS; do
```

## Output Formats

```bash
shellcheck script.sh                   # Default (human-readable)
shellcheck --format=gcc script.sh      # GCC (CI-friendly, one line per issue)
shellcheck --format=json script.sh     # JSON (for programmatic parsing)
shellcheck --format=checkstyle script.sh  # Checkstyle XML (Jenkins/SonarQube)
shellcheck --format=diff script.sh     # Diff format (auto-fixable issues)
shellcheck --format=quiet script.sh    # Quiet (exit code only)
```

## CI Integration

### Pre-commit Hook

```bash
#!/bin/bash
set -e
git diff --cached --name-only | grep '\.sh$' | while read -r script; do
    shellcheck "$script" || exit 1
done
```

### Pre-commit Framework (.pre-commit-config.yaml)

```yaml
repos:
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck
        args: ["--severity=warning"]
```

### GitHub Actions

```yaml
steps:
  - uses: actions/checkout@v4
  - name: ShellCheck
    uses: ludeeus/action-shellcheck@master
    with:
      severity: warning
      scandir: './scripts'
```

### GitLab CI

```yaml
shellcheck:
  stage: lint
  image: koalaman/shellcheck-alpine
  script: find . -name "*.sh" -exec shellcheck {} \;
```

### Makefile Target

```makefile
lint:
	@echo "Running ShellCheck..."
	@find . -name '*.sh' -not -path './vendor/*' -print0 | \
		xargs -0 -P 4 -n 1 shellcheck --format=gcc
	@echo "All scripts pass ShellCheck"
```

## Performance

### Parallel Checking

```bash
find . -name "*.sh" -print0 | xargs -0 -P 4 -n 1 shellcheck
```

### Caching Results

```bash
CACHE=".shellcheck_cache"
mkdir -p "$CACHE"
check_script() {
    local hash cache_file
    hash=$(sha256sum "$1" | cut -d' ' -f1)
    cache_file="$CACHE/$hash"
    if [[ ! -f "$cache_file" ]]; then
        shellcheck "$1" > "$cache_file" 2>&1 && touch "$cache_file.ok" || return 1
    fi
    [[ -f "$cache_file.ok" ]]
}
```

### Selective Severity

```bash
# Only errors (ignore warnings and info)
shellcheck --severity=error scripts/*.sh

# Errors and warnings (skip info/style)
shellcheck --severity=warning scripts/*.sh
```

## Editor Integration

| Editor | Plugin/Extension |
|--------|-----------------|
| VS Code | `timonwong.shellcheck` |
| Vim/Neovim | ALE, Syntastic, or built-in LSP with bash-language-server |
| Emacs | `flymake-shellcheck` |
| Sublime | `SublimeLinter-shellcheck` |

## Best Practices

1. Run ShellCheck in CI -- fail the build on issues
2. Target the correct shell (`--shell=bash` vs `--shell=sh`)
3. Document every `disable` comment with rationale
4. Fix violations rather than suppressing them
5. Use `--enable=all` with targeted exclusions
6. Keep ShellCheck updated for new checks
7. Use pre-commit hooks for early feedback
8. Integrate with your editor (VS Code, Vim, etc.)
9. Use `--format=diff` to see auto-fixable suggestions
10. Set `--severity=warning` as minimum CI threshold
