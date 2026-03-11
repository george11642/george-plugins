# Production Shell Logging

Complete logging library patterns for production shell scripts and services.

---

## 1. Core Structured Logging Library

Drop-in logging library for any shell script. Paste at the top of your script or source it:

```bash
#!/bin/bash
# logging-lib.sh — Production shell logging library
# Source with: source "$(dirname "$0")/logging-lib.sh"
# Or paste directly into your script.

# ─── Configuration ─────────────────────────────────────────────────────────────
LOG_LEVEL="${LOG_LEVEL:-INFO}"      # DEBUG | INFO | WARN | ERROR
LOG_FILE="${LOG_FILE:-}"            # Optional file path; empty = stderr only
LOG_JSON="${LOG_JSON:-false}"       # Set to "true" for JSON output
LOG_COLOR="${LOG_COLOR:-true}"      # Set to "false" to disable ANSI colors
SYSLOG_TAG="${SYSLOG_TAG:-}"        # Set to program name to also send to syslog

# ─── Internal constants ─────────────────────────────────────────────────────────
_LOG_LEVELS=("DEBUG" "INFO" "WARN" "ERROR")
declare -A _LOG_LEVEL_NUM=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)

# ANSI color codes
_C_RESET='\033[0m'
_C_GRAY='\033[0;37m'
_C_GREEN='\033[0;32m'
_C_YELLOW='\033[0;33m'
_C_RED='\033[0;31m'
_C_BOLD_RED='\033[1;31m'

declare -A _LOG_COLORS=(
    [DEBUG]="$_C_GRAY"
    [INFO]="$_C_GREEN"
    [WARN]="$_C_YELLOW"
    [ERROR]="$_C_RED"
)

# ─── Core logging function ──────────────────────────────────────────────────────
_log() {
    local level="$1"; shift
    local message="$*"
    local ts
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    # Level filtering
    local numeric_level="${_LOG_LEVEL_NUM[$level]:-1}"
    local numeric_threshold="${_LOG_LEVEL_NUM[${LOG_LEVEL}]:-1}"
    (( numeric_level >= numeric_threshold )) || return 0

    # Auto-detect context (caller location)
    local func="${FUNCNAME[2]:-main}"
    local line="${BASH_LINENO[1]:-0}"
    local source
    source="$(basename "${BASH_SOURCE[2]:-unknown}")"

    if [[ "$LOG_JSON" == "true" ]]; then
        # JSON structured output
        local json
        json=$(printf '{"ts":"%s","level":"%s","msg":%s,"func":"%s","file":"%s","line":%d}\n' \
            "$ts" "$level" "$(printf '%s' "$message" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().rstrip()))' 2>/dev/null || printf '"%s"' "$message")" \
            "$func" "$source" "$line")
        echo "$json" >&2
        [[ -n "$LOG_FILE" ]] && echo "$json" >> "$LOG_FILE"
    else
        # Human-readable output
        local color=""
        local reset=""
        if [[ "$LOG_COLOR" == "true" ]] && [[ -t 2 ]]; then
            color="${_LOG_COLORS[$level]:-}"
            reset="$_C_RESET"
        fi
        local formatted
        formatted=$(printf '%s%s [%s] %s (%s:%d)%s\n' \
            "$color" "$ts" "$level" "$message" "$source" "$line" "$reset")
        echo -e "$formatted" >&2
        if [[ -n "$LOG_FILE" ]]; then
            # Strip color codes when writing to file
            printf '%s [%s] %s (%s:%d)\n' "$ts" "$level" "$message" "$source" "$line" >> "$LOG_FILE"
        fi
    fi

    # Optional syslog forwarding
    if [[ -n "$SYSLOG_TAG" ]]; then
        local priority
        case "$level" in
            DEBUG) priority="user.debug" ;;
            INFO)  priority="user.info"  ;;
            WARN)  priority="user.warning" ;;
            ERROR) priority="user.err"   ;;
        esac
        logger -t "$SYSLOG_TAG" -p "$priority" "$message" 2>/dev/null || true
    fi
}

# ─── Public API ─────────────────────────────────────────────────────────────────
log_debug() { _log DEBUG "$@"; }
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }

# Fatal: log error and exit
log_fatal() {
    _log ERROR "$@"
    exit 1
}

# Log with explicit key=value fields (structured context)
log_with_fields() {
    local level="$1"; shift
    local message="$1"; shift
    local fields="$*"  # key=value pairs
    _log "$level" "$message $fields"
}
```

---

## 2. JSON Logging Format

For services consumed by log aggregators (ELK, Loki, CloudWatch, Datadog):

```bash
# Pure JSON logging without python dependency
log_json() {
    local level="$1"; shift
    local message="$*"
    local ts
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    # Escape double quotes in message
    local escaped_msg="${message//\"/\\\"}"
    printf '{"timestamp":"%s","level":"%s","message":"%s","pid":%d,"host":"%s"}\n' \
        "$ts" "$level" "$escaped_msg" "$$" "${HOSTNAME:-$(hostname)}" >&2
}

# With arbitrary extra fields (key=value pairs become JSON fields)
log_json_fields() {
    local level="$1" message="$2"; shift 2
    local ts pid host
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    pid=$$
    host="${HOSTNAME:-$(hostname)}"
    local escaped_msg="${message//\"/\\\"}"
    local extra=""
    local pair
    for pair in "$@"; do
        local key="${pair%%=*}"
        local val="${pair#*=}"
        extra+=",\"${key}\":\"${val//\"/\\\"}\""
    done
    printf '{"timestamp":"%s","level":"%s","message":"%s","pid":%d,"host":"%s"%s}\n' \
        "$ts" "$level" "$escaped_msg" "$pid" "$host" "$extra" >&2
}

# Usage:
log_json_fields "INFO" "Request processed" "method=POST" "path=/api/users" "duration_ms=42" "status=200"
# Output: {"timestamp":"2024-01-15T10:30:00Z","level":"INFO","message":"Request processed","pid":12345,"host":"myserver","method":"POST","path":"/api/users","duration_ms":"42","status":"200"}
```

---

## 3. Syslog Integration

```bash
# logger command: writes to syslog (journald on systemd systems)
# Syntax: logger [-t TAG] [-p FACILITY.PRIORITY] MESSAGE

# Syslog facilities
# user    — user-level messages (default)
# daemon  — system daemons
# cron    — cron/at daemons
# auth    — security/authentication messages
# local0-7 — locally-defined

# Syslog priorities (high to low)
# emerg alert crit err warning notice info debug

log_syslog() {
    local level="$1"; shift
    local tag="${SYSLOG_TAG:-$(basename "$0")}"
    local priority
    case "$level" in
        DEBUG) priority="user.debug"   ;;
        INFO)  priority="user.info"    ;;
        WARN)  priority="user.warning" ;;
        ERROR) priority="user.err"     ;;
        FATAL) priority="user.crit"    ;;
        *)     priority="user.info"    ;;
    esac
    logger -t "$tag" -p "$priority" -- "$*"
}

# Send to specific syslog server (UDP)
logger -t "myapp" -p local0.info -n syslog.example.com -P 514 "Remote syslog message"

# Check syslog output
journalctl -t myapp -f              # Follow logs from "myapp" tag
journalctl SYSLOG_IDENTIFIER=myapp  # journald native field
```

---

## 4. Journald Structured Fields

When running as a systemd service, stdout/stderr automatically go to journald with structured metadata:

```bash
# Check if running under systemd (JOURNAL_STREAM env var is set)
if [[ -n "${JOURNAL_STREAM:-}" ]]; then
    # We're under systemd journald
    # Use systemd-cat for richer structured fields
    echo "Service ready, version=1.2.3" | systemd-cat -t myapp -p info

    # Or use the journal socket directly via systemd-cat with heredoc
    systemd-cat -t "myapp" -p info <<< "Startup complete"

    # Multiple fields via journal protocol (advanced — requires socat or Python)
    # Each field: NAME=value, separated by newlines, sent to /run/systemd/journal/socket
fi

# Use systemd.journal-fields() prefix hints in stdout
# When StandardOutput=journal in service, these line prefixes set priority:
# <0> = emerg, <1> = alert, <2> = crit, <3> = err, <4> = warning,
# <5> = notice, <6> = info, <7> = debug
echo "<4>This will be logged as warning priority"
echo "<3>This will be logged as error priority"

# Practical: detect journal vs terminal and adapt output
if [[ -n "${JOURNAL_STREAM:-}" ]]; then
    # Running under journald — no need for timestamps (journald adds them)
    _LOG_FORMAT="[%s] %s"        # level, message
else
    # Running in terminal — add full timestamp
    _LOG_FORMAT="%s [%s] %s"     # timestamp, level, message
fi
```

---

## 5. Log Levels and Filtering

```bash
# Runtime level control via environment variable
export LOG_LEVEL=DEBUG   # Show all messages
export LOG_LEVEL=INFO    # Default — skip debug
export LOG_LEVEL=WARN    # Only warnings and errors
export LOG_LEVEL=ERROR   # Errors only

# Dynamic level change via signal (e.g., SIGUSR1 toggles debug)
_DEBUG_MODE=false

_toggle_debug() {
    if $_DEBUG_MODE; then
        _DEBUG_MODE=false
        LOG_LEVEL=INFO
        log_info "Debug mode DISABLED"
    else
        _DEBUG_MODE=true
        LOG_LEVEL=DEBUG
        log_info "Debug mode ENABLED"
    fi
}

trap '_toggle_debug' SIGUSR1
# Now: kill -USR1 $PID  toggles debug mode without restart

# Verbose flag shorthand
VERBOSE="${VERBOSE:-false}"
vlog() { $VERBOSE && log_debug "$@" || true; }
```

---

## 6. BASH_LINENO and FUNCNAME for Auto-context

```bash
# Access the call stack anywhere
print_stack() {
    local i=0
    echo "Call stack:" >&2
    while [[ -n "${FUNCNAME[$i]:-}" ]]; do
        printf '  [%d] %s() at %s:%d\n' \
            "$i" \
            "${FUNCNAME[$i]}" \
            "${BASH_SOURCE[$i]:-unknown}" \
            "${BASH_LINENO[$((i-1))]:-0}" >&2
        ((i++))
    done
}

# Get caller info for log messages
_caller_context() {
    # FUNCNAME[0]=_caller_context, [1]=_log, [2]=log_info, [3]=actual caller
    local depth="${1:-3}"
    printf '%s:%d' "$(basename "${BASH_SOURCE[$depth]:-unknown}")" "${BASH_LINENO[$((depth-1))]:-0}"
}

# ERR trap that logs a stack trace
_on_error() {
    local exit_code=$?
    local line_number="${BASH_LINENO[0]}"
    log_error "Command failed with exit code $exit_code at line $line_number"
    log_error "Failed command: $BASH_COMMAND"
    print_stack
}
trap '_on_error' ERR
```

---

## 7. Log Rotation with SIGHUP Signal Handling

```bash
#!/bin/bash
# Long-running service that supports log rotation via SIGHUP

LOG_FILE="/var/log/myapp/app.log"
LOG_FD=

_open_log() {
    [[ -n "${LOG_FD:-}" ]] && exec {LOG_FD}>&- 2>/dev/null || true
    mkdir -p "$(dirname "$LOG_FILE")"
    exec {LOG_FD}>>"$LOG_FILE"
    log_info "Opened log file: $LOG_FILE (fd=$LOG_FD)"
}

_rotate_log() {
    log_info "Received SIGHUP — reopening log file for rotation"
    _open_log
}

trap '_rotate_log' SIGHUP

_open_log

# Now all logging uses $LOG_FD
_write_log() {
    local ts
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    printf '%s [%s] %s\n' "$ts" "$1" "$2" >&${LOG_FD}
}

# With logrotate config:
# /var/log/myapp/*.log {
#     daily
#     rotate 14
#     compress
#     missingok
#     notifempty
#     postrotate
#         kill -HUP $(cat /run/myapp.pid)
#     endscript
# }
```

---

## 8. Performance Logging with DEBUG Trap

```bash
# Instrument every command for timing (use in DEBUG builds only)
_LAST_CMD_TIME=0
_PERF_LOG="/tmp/perf-$$.log"

_perf_trace() {
    local now
    now=$(date +%s%N)  # nanoseconds
    if [[ $_LAST_CMD_TIME -gt 0 ]]; then
        local elapsed=$(( (now - _LAST_CMD_TIME) / 1000000 ))  # ms
        printf '%s  %dms  %s\n' "$(date +'%H:%M:%S.%N' | cut -c1-12)" "$elapsed" "$BASH_COMMAND" >> "$_PERF_LOG"
    fi
    _LAST_CMD_TIME=$now
}

enable_perf_trace() {
    _LAST_CMD_TIME=$(date +%s%N)
    trap '_perf_trace' DEBUG
    log_info "Performance tracing enabled — output: $_PERF_LOG"
}

disable_perf_trace() {
    trap - DEBUG
    log_info "Performance tracing disabled — results in: $_PERF_LOG"
}

# Usage: wrap slow section
enable_perf_trace
# ... your code here ...
disable_perf_trace

# View slowest commands
sort -t' ' -k2 -rn "$_PERF_LOG" | head -20
```

---

## 9. Complete Logging Library (Single File)

Ready-to-source logging library at `~/.local/lib/bash/logging.sh`:

```bash
#!/bin/bash
# ~/.local/lib/bash/logging.sh
# Source: source ~/.local/lib/bash/logging.sh

LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
LOG_JSON="${LOG_JSON:-false}"
SYSLOG_TAG="${SYSLOG_TAG:-}"

declare -A _LVL=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
declare -A _CLR=([DEBUG]='\033[37m' [INFO]='\033[32m' [WARN]='\033[33m' [ERROR]='\033[31m')
_RST='\033[0m'

_log() {
    local lvl="$1"; shift
    (( ${_LVL[$lvl]:-1} >= ${_LVL[${LOG_LEVEL}]:-1} )) || return 0
    local ts func src line msg="$*"
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    func="${FUNCNAME[2]:-main}"
    src="$(basename "${BASH_SOURCE[2]:-?}")"
    line="${BASH_LINENO[1]:-0}"

    if [[ "$LOG_JSON" == "true" ]]; then
        local esc="${msg//\"/\\\"}"
        printf '{"ts":"%s","lvl":"%s","msg":"%s","fn":"%s","src":"%s:%d","pid":%d}\n' \
            "$ts" "$lvl" "$esc" "$func" "$src" "$line" "$$"
    else
        local c="" r=""
        [[ -t 2 ]] && { c="${_CLR[$lvl]:-}"; r="$_RST"; }
        printf "${c}%s %-5s %s (%s:%d)${r}\n" "$ts" "$lvl" "$msg" "$src" "$line"
    fi >&2

    [[ -n "$LOG_FILE" ]] && \
        printf '%s %-5s %s (%s:%d)\n' "$ts" "$lvl" "$msg" "$src" "$line" >> "$LOG_FILE"

    [[ -n "$SYSLOG_TAG" ]] && {
        local p; case "$lvl" in
            DEBUG) p=debug ;; INFO) p=info ;; WARN) p=warning ;; ERROR) p=err ;;
        esac
        logger -t "$SYSLOG_TAG" -p "user.$p" "$msg" 2>/dev/null || true
    }
}

log_debug() { _log DEBUG "$@"; }
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }
log_fatal() { _log ERROR "$@"; exit 1; }

# Trap setup
setup_error_trap() {
    trap 'log_error "Command failed: $BASH_COMMAND (exit $?) at ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"' ERR
}

# Check if log level is active (useful for avoiding expensive string building)
is_debug() { (( ${_LVL[DEBUG]} >= ${_LVL[${LOG_LEVEL}]} )); }
```
