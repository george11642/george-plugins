# Defensive Bash Patterns Reference

Detailed patterns for production-grade shell scripting. Parent skill: [../SKILL.md](../SKILL.md)

## Strict Mode

```bash
#!/bin/bash
set -Eeuo pipefail
```

- `-E`: ERR trap inherited by functions
- `-e`: Exit on any non-zero return
- `-u`: Exit on undefined variable
- `-o pipefail`: Pipe fails if any command fails

## Error Trapping and Cleanup

```bash
trap 'echo "Error on line $LINENO" >&2' ERR
trap 'rm -rf -- "$TMPDIR"' EXIT

TMPDIR=$(mktemp -d) || { echo "Failed to create temp dir" >&2; exit 1; }
```

### Stack Trace on Error

Print the full call stack when an error occurs -- invaluable for debugging nested function calls:

```bash
trap '_rc=$?; echo "ERROR in ${FUNCNAME[0]:-main} at line $LINENO (exit $?)" >&2; \
  for ((i=0; i<${#FUNCNAME[@]}; i++)); do \
    echo "  ${FUNCNAME[$i]}() at ${BASH_SOURCE[$i]}:${BASH_LINENO[$i]}" >&2; \
  done; exit $_rc' ERR
```

### Extended Stack Trace (Loop-Based)

A cleaner loop-based version suitable for sourcing as a library function:

```bash
print_stack_trace() {
    local i
    echo "Stack trace (most recent first):" >&2
    for (( i = 1; i < ${#FUNCNAME[@]}; i++ )); do
        printf '  [%d] %s() called from %s:%s\n' \
            "$i" \
            "${FUNCNAME[$i]:-main}" \
            "${BASH_SOURCE[$i]:-unknown}" \
            "${BASH_LINENO[$i-1]}" >&2
    done
}

on_error() {
    local rc=$?
    echo "ERROR: command '${BASH_COMMAND}' exited with status ${rc}" >&2
    print_stack_trace
    exit "$rc"
}
trap on_error ERR
```

### Multi-Signal Trapping

Handle different cleanup scenarios for different signals:

```bash
cleanup() { rm -rf -- "$TMPDIR"; }
on_error() { log_error "Failed at line $LINENO"; cleanup; }
on_interrupt() { log_warn "Interrupted by user"; cleanup; exit 130; }

trap on_error ERR
trap cleanup EXIT
trap on_interrupt SIGINT SIGTERM
```

## Variable Safety

```bash
# Always quote
cp "$source" "$dest"

# Required variable with error message
: "${REQUIRED_VAR:?REQUIRED_VAR is not set}"

# Default value
value="${OPTIONAL_VAR:-default}"

# Assign default if unset (mutates the variable)
: "${CACHE_DIR:=/tmp/cache}"

# Safe empty check
if [[ -z "${VAR:-}" ]]; then echo "VAR is not set or empty"; fi
```

## Array Handling

```bash
declare -a items=("item 1" "item 2" "item 3")
for item in "${items[@]}"; do echo "$item"; done

# Read command output into array
mapfile -t lines < <(some_command)

# NUL-safe file iteration
while IFS= read -r -d '' file; do
    echo "Processing: $file"
done < <(find /path -type f -print0)
```

## Process Substitution and Here Strings

Process substitution creates file descriptors from command output -- use to avoid subshell variable scoping issues:

```bash
# Compare two command outputs without temp files
diff <(sort file1.txt) <(sort file2.txt)

# Feed command output as a file to programs that require file args
wc -l <(grep -r "pattern" /path)

# Here string -- feed a string to stdin without echo|pipe
read -r first rest <<< "$line"
grep -q "pattern" <<< "$input"

# Here string with variable -- avoids a subshell
while IFS=: read -r user _ uid _; do
    echo "$user has UID $uid"
done <<< "$(getent passwd root)"
```

## Script Directory Detection

```bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
```

## Function Template

```bash
validate_file() {
    local -r file="$1"
    local -r message="${2:-File not found: $file}"
    [[ -f "$file" ]] || { echo "ERROR: $message" >&2; return 1; }
}

process_files() {
    local -r input_dir="$1"
    local -r output_dir="$2"
    [[ -d "$input_dir" ]] || { echo "ERROR: Not a directory" >&2; return 1; }
    mkdir -p "$output_dir"
    while IFS= read -r -d '' file; do
        echo "Processing: $file"
    done < <(find "$input_dir" -maxdepth 1 -type f -print0)
}
```

## Argument Parsing

```bash
VERBOSE=false
DRY_RUN=false
OUTPUT_FILE=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]
Options:
    -v, --verbose       Enable verbose output
    -d, --dry-run       Preview changes
    -o, --output FILE   Output file path
    -h, --help          Show help
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose) VERBOSE=true; shift ;;
        -d|--dry-run) DRY_RUN=true; shift ;;
        -o|--output)  OUTPUT_FILE="$2"; shift 2 ;;
        -h|--help)    usage 0 ;;
        --)           shift; break ;;
        *)            echo "ERROR: Unknown option: $1" >&2; usage 1 ;;
    esac
done
```

## Named Parameters (Functions)

```bash
process_data() {
    local input_file="" output_dir="" format="json"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --input=*)  input_file="${1#*=}" ;;
            --output=*) output_dir="${1#*=}" ;;
            --format=*) format="${1#*=}" ;;
            *)          echo "ERROR: Unknown: $1" >&2; return 1 ;;
        esac
        shift
    done
    [[ -n "$input_file" ]] || { echo "ERROR: --input required" >&2; return 1; }
}
```

## Structured Logging

```bash
LOG_LEVEL="${LOG_LEVEL:-INFO}"
_log() {
    local level="$1"; shift
    local -A levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
    (( levels[$level] >= levels[${LOG_LEVEL}] )) || return 0
    printf '[%s] %s: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$level" "$*" >&2
}
log_info()  { _log INFO "$@"; }
log_warn()  { _log WARN "$@"; }
log_error() { _log ERROR "$@"; }
log_debug() { _log DEBUG "$@"; }

# Syslog integration for services/daemons
logger -t "${SCRIPT_NAME:-myapp}" -p user.info "Started successfully"
logger -t "${SCRIPT_NAME:-myapp}" -p user.err "Fatal: $error_msg"
```

## Process Orchestration

```bash
PIDS=()
cleanup() {
    for pid in "${PIDS[@]}"; do
        kill -0 "$pid" 2>/dev/null && kill -TERM "$pid" 2>/dev/null || true
    done
    for pid in "${PIDS[@]}"; do wait "$pid" 2>/dev/null || true; done
}
trap cleanup SIGTERM SIGINT

background_task & PIDS+=($!)
wait
```

### Coproc (Bidirectional IPC)

Use coproc for two-way communication with a background process:

```bash
coproc WORKER { while read -r cmd; do
    echo "processed: $cmd"
done; }

echo "task1" >&"${WORKER[1]}"
read -r result <&"${WORKER[0]}"
echo "$result"  # "processed: task1"
```

## Safe File Operations

```bash
# Atomic write: write to temp, then move
# Ensures readers never see a partially-written file.
atomic_write() {
    local -r target="$1"
    local tmpfile
    tmpfile=$(mktemp "${target}.XXXXXX") || { echo "ERROR: mktemp failed" >&2; return 1; }
    # Ensure temp file is removed on any failure
    trap 'rm -f -- "$tmpfile"' RETURN
    cat > "$tmpfile" || { echo "ERROR: write to temp file failed" >&2; return 1; }
    mv -- "$tmpfile" "$target" || { echo "ERROR: atomic rename failed" >&2; return 1; }
}

# Safe move (no overwrite)
safe_move() {
    local -r src="$1" dest="$2"
    [[ -e "$src" ]]  || { echo "ERROR: Source missing" >&2; return 1; }
    [[ ! -e "$dest" ]] || { echo "ERROR: Dest exists" >&2; return 1; }
    mv "$src" "$dest"
}

# Lock file for mutual exclusion
LOCKFILE="/var/lock/myapp.lock"
exec 9>"$LOCKFILE"
flock -n 9 || { echo "Another instance running" >&2; exit 1; }
```

## Idempotent Design

```bash
ensure_directory() {
    local -r dir="$1"
    [[ -d "$dir" ]] && return 0
    mkdir -p "$dir"
}

ensure_config() {
    local -r config="$1" default="$2"
    [[ -f "$config" ]] || echo "$default" > "$config"
}
```

## Dry-Run Support

```bash
DRY_RUN="${DRY_RUN:-false}"
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] $*"; return 0
    fi
    "$@"
}
run_cmd cp "$source" "$dest"
```

## Dependency Checking

```bash
check_dependencies() {
    local -a missing=()
    local -a required=("jq" "curl" "git")
    for cmd in "${required[@]}"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing: ${missing[*]}" >&2; return 1
    fi
}
```

## Debugging Techniques

```bash
# Trace execution with custom prefix
set -x
export PS4='+${BASH_SOURCE[0]}:${FUNCNAME[0]:-main}:${LINENO}: '

# Selective tracing -- wrap only the suspect section
set -x
  suspect_function "$arg"
set +x

# DEBUG trap for profiling (runs before every command)
_start_time=$(date +%s%N)
trap 'now=$(date +%s%N); \
  elapsed=$(( (now - _start_time) / 1000000 )); \
  echo "${elapsed}ms: $BASH_COMMAND" >&2; \
  _start_time=$now' DEBUG

# Inspect variables at a breakpoint
debug_break() {
    echo "=== DEBUG at ${BASH_SOURCE[1]}:${BASH_LINENO[0]} ===" >&2
    local var; for var in "$@"; do
        echo "  $var=${!var:-<unset>}" >&2
    done
}
```
