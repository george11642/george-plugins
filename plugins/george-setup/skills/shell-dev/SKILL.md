---
name: shell-dev
description: Use when writing shell scripts, Bash/Zsh/Fish/sh automation, CLI tools, deploy scripts, infrastructure automation, systemd services, cron jobs, process management, shell plugins, shell completions, tab completion scripts, installer scripts, log processing, or configuring ShellCheck and BATS testing. Triggers on bash, zsh, fish, shell script, .sh file, shebang, #!/bin/bash, dotfiles, shell functions, aliases, shell configuration, .bashrc, .zshrc, interactive menus, select loops, getopts, getopt, argument parsing in shell, bidirectional IPC, coproc, file locking, flock, mutual exclusion, spy pattern, call recording, POSIX compliance, severity levels, pre-commit framework, parallel testing, atomic operations, signal handling, stack trace, skip_if, bats-assert, shellcheck severity, check-sourced, atomic write, awk, sed, text processing, log analysis, stream processing, curl, wget, HTTP in shell, API calls from shell, download with retry, systemd unit file, systemd timer, journald, journalctl, logger, syslog, xargs parallel, gnu parallel, parallel execution, job control, process pool, PS4, BASH_XTRACEFD, DEBUG trap, ERR trap, bashdb, set -x tracing, structured logging, JSON logging, production logging.
---

# Shell Development

Master skill for defensive Bash programming, BATS testing, and ShellCheck static analysis. Covers production-grade scripting patterns, CLI tool creation, debugging, logging, service management, text processing, HTTP networking, and automated testing.

## Quick Reference

| Topic | Reference |
|-------|-----------|
| Defensive patterns | [references/defensive.md](references/defensive.md) |
| BATS testing | [references/bats-testing.md](references/bats-testing.md) |
| ShellCheck config | [references/shellcheck.md](references/shellcheck.md) |
| Argument parsing (getopts, getopt, subcommands) | [references/argument-parsing.md](references/argument-parsing.md) |
| systemd services and timers | [references/systemd-services.md](references/systemd-services.md) |
| Text processing (awk, sed, pipelines) | [references/text-processing.md](references/text-processing.md) |
| Production logging (structured, JSON, syslog) | [references/logging-production.md](references/logging-production.md) |
| HTTP/networking (curl, wget, retry, APIs) | [references/http-networking.md](references/http-networking.md) |
| Parallel execution (xargs, GNU parallel, pools) | [references/parallel-execution.md](references/parallel-execution.md) |
| Advanced debugging (PS4, BASH_XTRACEFD, traps) | [references/debugging-advanced.md](references/debugging-advanced.md) |

## Task Router

| Task | Go-to Reference |
|------|----------------|
| Parse `-v`, `--verbose`, long options | `argument-parsing.md` → getopts / getopt |
| Build git-style subcommand CLI | `argument-parsing.md` → subcommand routing |
| Validate CLI arguments (type, range, enum) | `argument-parsing.md` → validation patterns |
| Create systemd service for a script | `systemd-services.md` → unit file examples |
| Replace cron with systemd timer | `systemd-services.md` → timers |
| Handle SIGTERM gracefully | `systemd-services.md` → graceful shutdown |
| Log to journald from a service | `systemd-services.md` → journald integration |
| Extract fields from text/CSV/logs | `text-processing.md` → awk one-liners |
| Replace/transform text with sed | `text-processing.md` → sed patterns |
| Analyze log files | `text-processing.md` → log analysis |
| awk associative arrays / frequency count | `text-processing.md` → awk arrays |
| Structured log_info / log_error with levels | `logging-production.md` → core library |
| JSON logging for log aggregators | `logging-production.md` → JSON format |
| Log rotation with SIGHUP | `logging-production.md` → log rotation |
| Write to syslog from shell | `logging-production.md` → syslog integration |
| curl API calls with auth and error handling | `http-networking.md` → api_call_with_backoff |
| Download files with retry and resume | `http-networking.md` → download_with_retry |
| Check if port is open | `http-networking.md` → check_port |
| Rate-limit API calls | `http-networking.md` → rate limiting |
| Parallel file processing with xargs | `parallel-execution.md` → xargs -P |
| GNU parallel basics and advanced | `parallel-execution.md` → GNU parallel |
| Bounded process pool | `parallel-execution.md` → process pool |
| Error propagation from parallel jobs | `parallel-execution.md` → error propagation |
| Enable set -x with timestamps | `debugging-advanced.md` → PS4 patterns |
| Route trace output to file | `debugging-advanced.md` → BASH_XTRACEFD |
| Profile slow commands | `debugging-advanced.md` → DEBUG trap |
| Print stack trace on error | `debugging-advanced.md` → ERR trap |
| Interactive breakpoint in script | `debugging-advanced.md` → debug_break |
| ShellCheck suppression and config | `shellcheck.md` |
| BATS test setup, mocking, fixtures | `bats-testing.md` |
| Defensive patterns, traps, atomicity | `defensive.md` |

## Script Template

Every production script starts with this skeleton:

```bash
#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

trap 'echo "Error on line $LINENO" >&2' ERR
trap 'rm -rf -- "${TMPDIR:-}"' EXIT

TMPDIR=$(mktemp -d)

log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*" >&2; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -v, --verbose   Enable verbose output
    -h, --help      Show this help
EOF
    exit "${1:-0}"
}
```

## Core Defensive Rules

1. **Always `set -Eeuo pipefail`** -- strict mode catches errors early
2. **Quote all variables** -- `"$var"` prevents word splitting and globbing
3. **Use `[[ ]]` over `[ ]`** -- safer conditionals in Bash
4. **Trap ERR and EXIT** -- clean up temp files, log failures
5. **Validate inputs** -- check file existence, required vars with `${VAR:?msg}`
6. **Use `command -v`** -- safer than `which` for dependency checks
7. **Use `$()` not backticks** -- nestable, readable command substitution
8. **Iterate safely** -- `find -print0 | while read -r -d ''` for filenames with spaces
9. **Atomic writes** -- write to temp file, then `mv` to target
10. **Design for idempotency** -- safe to re-run without side effects

## Argument Parsing Pattern

```bash
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose) VERBOSE=true; shift ;;
        -o|--output)  OUTPUT="$2"; shift 2 ;;
        -h|--help)    usage 0 ;;
        --)           shift; break ;;
        *)            echo "ERROR: Unknown option: $1" >&2; usage 1 ;;
    esac
done
```

## Safe Patterns Cheat Sheet

| Need | Pattern |
|------|---------|
| Required var | `${VAR:?VAR is not set}` |
| Default value | `${VAR:-default}` |
| Temp directory | `TMPDIR=$(mktemp -d)` with EXIT trap |
| File iteration | `find . -print0 \| while IFS= read -r -d '' f` |
| Array from cmd | `mapfile -t arr < <(command)` |
| Process substitution | `diff <(cmd1) <(cmd2)` |
| Here string | `read -r var <<< "$input"` |
| Dry-run support | Wrap commands in `run_cmd()` that checks `$DRY_RUN` |
| Dependency check | `command -v jq &>/dev/null \|\| { echo "missing jq"; exit 1; }` |
| Background procs | Track PIDs in array, `trap cleanup SIGTERM SIGINT` |

## Debugging

Use these techniques to trace script execution and diagnose failures:

```bash
# Enable trace mode -- prints each command before execution
set -x

# Custom trace prefix showing file, function, and line number
export PS4='+${BASH_SOURCE[0]}:${FUNCNAME[0]:-main}:${LINENO}: '

# Trace specific sections only
set -x
  problematic_code_here
set +x

# DEBUG trap -- runs before every command (use for logging/profiling)
trap 'echo "CMD: $BASH_COMMAND" >&2' DEBUG

# Print call stack on error (add to ERR trap)
trap 'echo "Error in ${FUNCNAME[0]:-main} at line $LINENO"; \
  for i in "${!FUNCNAME[@]}"; do \
    echo "  ${FUNCNAME[$i]}() at ${BASH_SOURCE[$i]}:${BASH_LINENO[$i]}"; \
  done' ERR
```

## Logging Best Practices

```bash
# Structured logging with levels -- always log to stderr
LOG_LEVEL="${LOG_LEVEL:-INFO}"
_log() {
    local level="$1"; shift
    local -A levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
    (( levels[$level] >= levels[${LOG_LEVEL}] )) || return 0
    printf '[%s] %s: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$level" "$*" >&2
}
log_debug() { _log DEBUG "$@"; }
log_info()  { _log INFO "$@"; }
log_warn()  { _log WARN "$@"; }
log_error() { _log ERROR "$@"; }

# Log to syslog for daemon/service scripts
logger -t "myapp" -p user.info "Service started"
logger -t "myapp" -p user.err "Fatal error: $msg"
```

## BATS Testing Essentials

### Test File Structure

```bash
#!/usr/bin/env bats

setup() {
    TEST_DIR=$(mktemp -d)
    source "${BATS_TEST_DIRNAME}/../bin/script.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "function returns 0 on valid input" {
    run my_function "good_input"
    [ "$status" -eq 0 ]
}

@test "function fails on missing arg" {
    run my_function
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}
```

### Key BATS Patterns

- **`run` keyword** captures `$status`, `$output`, and `${lines[@]}`
- **`setup_file` / `teardown_file`** run once per file (expensive setup)
- **`setup` / `teardown`** run per test (isolation)
- **`skip`** conditionally skip: `command -v jq &>/dev/null || skip "jq not installed"`
- **Mocking** -- override functions or prepend stub dir to `$PATH`
- **Fixtures** -- store in `tests/fixtures/`, copy to temp dir in setup

### Running Tests

```bash
bats tests/*.bats              # Run all tests
bats tests/*.bats --tap        # TAP output for CI
bats tests/*.bats --parallel 4 # Parallel execution
```

## ShellCheck Essentials

### Project Config (`.shellcheckrc`)

```
shell=bash
enable=avoid-nullary-conditions,require-variable-braces
disable=SC1091
external-sources=true
```

### Critical Error Codes

| Code | Issue | Fix |
|------|-------|-----|
| SC2086 | Unquoted variable | Add double quotes |
| SC2181 | Indirect `$?` check | Use `if command; then` |
| SC2015 | `&& \|\|` as if-else | Use proper if-then-else |
| SC2009 | `grep` on `ps` output | Use `pgrep` |
| SC1091 | Can't follow source | Add `# shellcheck source=path` |

## Best Practices Summary

1. Start every script with strict mode and traps
2. Write tests alongside scripts -- BATS makes it easy
3. Run ShellCheck in CI and as a pre-commit hook
4. Test both success and failure paths
5. Use `set -x` and custom `PS4` for debugging -- remove before commit
6. Log to stderr with structured levels; use syslog for services
7. Prefer `printf` over `echo` for portable output
8. Document ShellCheck suppressions -- explain the "why"
9. Keep functions small with `local -r` for immutable locals
10. Use `find -print0` and `read -d ''` for safe file iteration
