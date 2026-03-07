# Advanced Shell Debugging

set -x, PS4, BASH_XTRACEFD, DEBUG trap, ERR trap stack traces, and a complete debug library.

---

## 1. set -x with PS4 Formatting

`set -x` prints each command before execution. `PS4` controls the trace prefix.

```bash
# Default PS4 is '+ ' — not very informative
set -x
ls /tmp    # Output: + ls /tmp

# Custom PS4: show file, function, and line number
export PS4='+${BASH_SOURCE[0]##*/}:${FUNCNAME[0]:-main}:${LINENO}: '
set -x
# Output: +script.sh:main:42: ls /tmp

# Add timestamps to trace (nanosecond resolution)
export PS4='+[$(date +%T.%N | cut -c1-15)] ${BASH_SOURCE[0]##*/}:${FUNCNAME[0]:-main}:${LINENO}: '
set -x
# Output: +[10:30:45.123456789] script.sh:main:42: ls /tmp

# Nested call depth indicator (shows call stack depth visually)
export PS4='${BASH_SOURCE[0]##*/}:${FUNCNAME[0]:-main}:${LINENO}:${SHLVL}: '

# Color-coded trace (errors stand out in terminal)
export PS4='\033[33m+\033[0m ${BASH_SOURCE[0]##*/}:${LINENO}: '

# Trace only specific sections
debug_start() {
    export PS4='+${BASH_SOURCE[0]##*/}:${FUNCNAME[0]:-main}:${LINENO}: '
    set -x
}
debug_stop() {
    set +x
}

# Usage:
debug_start
  expensive_function "$arg"
  another_call
debug_stop
```

---

## 2. BASH_XTRACEFD — Route Trace Output

By default `set -x` writes to stderr (fd 2). `BASH_XTRACEFD` redirects it to a specific file descriptor.

```bash
# Redirect trace to a log file (keeps stderr clean)
exec 9>/tmp/trace-$$.log           # Open fd 9 writing to trace file
export BASH_XTRACEFD=9             # Direct set -x output to fd 9
export PS4='+${BASH_SOURCE[0]##*/}:${LINENO}: '
set -x
# All trace output goes to /tmp/trace-$$.log, not stderr

# Cleanup
set +x
exec 9>&-    # Close fd 9

# Combined: trace to file AND stderr
exec 8> >(tee /tmp/trace-$$.log >&2)
export BASH_XTRACEFD=8
set -x

# Trace to syslog
exec 7> >(logger -t "${0##*/}-trace" -p user.debug)
export BASH_XTRACEFD=7
set -x

# Named pipe for real-time trace processing
mkfifo /tmp/trace-pipe
cat /tmp/trace-pipe | grep -v '^+[+]' > /tmp/trace-filtered.log &
exec 6>/tmp/trace-pipe
export BASH_XTRACEFD=6
set -x
```

---

## 3. DEBUG Trap for Per-command Profiling

The DEBUG trap fires before every simple command executes.

```bash
# Basic command logger
trap 'echo "CMD: $BASH_COMMAND" >&2' DEBUG

# Timestamp each command (microsecond-level profiling)
_LAST_TIME=$(date +%s%N 2>/dev/null || date +%s)
_PROFILE_LOG="/tmp/profile-$$.log"

_profile_debug() {
    local now
    now=$(date +%s%N 2>/dev/null || echo 0)
    local elapsed_ms=$(( (now - _LAST_TIME) / 1000000 ))
    printf '%6dms  %s\n' "$elapsed_ms" "$BASH_COMMAND" >> "$_PROFILE_LOG"
    _LAST_TIME=$now
}

trap '_profile_debug' DEBUG

# After script: view slowest commands
sort -rn "$_PROFILE_LOG" | head -20

# Selective profiling of a block
enable_profiling() {
    _LAST_TIME=$(date +%s%N)
    trap '_profile_debug' DEBUG
}
disable_profiling() {
    trap - DEBUG
    echo "Profile saved to: $_PROFILE_LOG" >&2
}

enable_profiling
    # ... code to profile ...
disable_profiling

# Variable watchpoint: detect when a variable changes
_watched_var_value=""
watch_var() {
    local varname="$1"
    _watched_var_value="${!varname}"
    trap '
        local _cur
        _cur="${'"$varname"'}"
        if [[ "$_cur" != "$_watched_var_value" ]]; then
            echo "WATCH: '"$varname"' changed: '\''$_watched_var_value'\'' -> '\''$_cur'\'' at $BASH_COMMAND" >&2
            _watched_var_value="$_cur"
        fi
    ' DEBUG
}
```

---

## 4. ERR Trap with Stack Trace

The ERR trap fires whenever a command exits with a non-zero status (with `set -E`).

```bash
#!/bin/bash
set -Eeuo pipefail

# Full stack trace on error
_on_error() {
    local exit_code=$?
    local line_no="${BASH_LINENO[0]}"
    local command="$BASH_COMMAND"

    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "ERROR: Command failed (exit code: $exit_code)" >&2
    echo "Command: $command" >&2
    echo "Location: ${BASH_SOURCE[1]:-unknown}:$line_no" >&2
    echo "" >&2
    echo "Stack trace:" >&2

    local i
    for (( i=1; i<${#FUNCNAME[@]}; i++ )); do
        local func="${FUNCNAME[$i]:-main}"
        local src="${BASH_SOURCE[$i]:-unknown}"
        local lineno="${BASH_LINENO[$((i-1))]:-0}"
        printf '  [%d] %s() at %s:%d\n' "$i" "$func" "$src" "$lineno" >&2
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
}

trap '_on_error' ERR

# Example to trigger the trap:
function_c() { false; }                                # Will fail
function_b() { function_c; }
function_a() { function_b; }
function_a
# Output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ERROR: Command failed (exit code: 1)
# Command: false
# Location: script.sh:47
#
# Stack trace:
#   [1] function_c() at script.sh:47
#   [2] function_b() at script.sh:48
#   [3] function_a() at script.sh:49
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 5. Conditional Tracing with TRACE=1

```bash
#!/bin/bash
# Enable verbose tracing only when TRACE=1 is set
# Usage: TRACE=1 ./script.sh  OR  TRACE=1 bash ./script.sh

if [[ "${TRACE:-0}" == "1" ]]; then
    export PS4='+[${EPOCHREALTIME}] ${BASH_SOURCE[0]##*/}:${FUNCNAME[0]:-main}:${LINENO}: '
    set -x
fi

# VERBOSE mode (less noisy than TRACE)
VERBOSE="${VERBOSE:-false}"
log_verbose() { $VERBOSE && echo "[VERBOSE] $*" >&2 || true; }

# Trace a specific function
trace_func() {
    local func="$1"
    eval "
_orig_${func}() { ${func} \"\$@\"; }
${func}() {
    echo \"ENTER: ${func}(\$*)\" >&2
    set -x
    _orig_${func} \"\$@\"
    local _rc=\$?
    set +x
    echo \"EXIT: ${func}() -> \$_rc\" >&2
    return \$_rc
}
"
}

# Usage: TRACE=1 ./script.sh
#        VERBOSE=true ./script.sh
```

---

## 6. Trap-based Breakpoint Function

Simulates a debugger breakpoint — pauses execution and lets you inspect state.

```bash
# Interactive breakpoint (requires a terminal)
debug_break() {
    local label="${1:-BREAKPOINT}"
    echo "" >&2
    echo "=== $label ===" >&2
    echo "File:     ${BASH_SOURCE[1]:-unknown}" >&2
    echo "Function: ${FUNCNAME[1]:-main}" >&2
    echo "Line:     ${BASH_LINENO[0]}" >&2
    echo "" >&2
    echo "Variables in scope (set | grep ...)? Type 'c' to continue, 'q' to quit" >&2
    echo "" >&2

    while IFS= read -r -p "(debug) " input; do
        case "$input" in
            c|continue) break ;;
            q|quit)     echo "Aborted at $label" >&2; exit 1 ;;
            "")         break ;;
            *)          eval "$input" ;;     # Execute arbitrary shell code!
        esac
    done
    echo "=== Continuing ===" >&2
}

# Non-interactive breakpoint (just dumps state and continues)
debug_checkpoint() {
    local label="${1:-CHECKPOINT}"
    echo "=== $label ===" >&2
    echo "  PID: $$   Line: ${BASH_LINENO[0]}" >&2
    echo "  Function stack: ${FUNCNAME[*]}" >&2
    echo "  Relevant vars:" >&2
    # Print all non-readonly variables (customize as needed)
    set | grep -v '^_\|^BASH\|^COMP\|^DIRSTACK\|^EUID' | head -30 >&2
    echo "==================" >&2
}

# Usage:
process_batch() {
    local batch_id="$1"
    debug_break "Before processing batch $batch_id"  # Pause here
    do_work "$batch_id"
    debug_checkpoint "After batch $batch_id"         # Log state and continue
}
```

---

## 7. Variable Inspection Patterns

```bash
# Print all variables matching a pattern
inspect_vars() {
    local pattern="${1:-}"
    echo "=== Variable Inspection ===" >&2
    if [[ -n "$pattern" ]]; then
        set | grep "^${pattern}" >&2
    else
        declare -p >&2   # All declared variables with types
    fi
}

# Print array contents
dump_array() {
    local name="$1"
    local -n arr="$name"   # nameref (Bash 4.3+)
    echo "Array '$name' (${#arr[@]} elements):" >&2
    local i
    for i in "${!arr[@]}"; do
        printf '  [%d] = %q\n' "$i" "${arr[$i]}" >&2
    done
}

# Associative array inspection
dump_assoc() {
    local name="$1"
    local -n map="$name"
    echo "Assoc array '$name' (${#map[@]} keys):" >&2
    local k
    for k in "${!map[@]}"; do
        printf '  [%q] = %q\n' "$k" "${map[$k]}" >&2
    done
}

# Type and value of any variable
what_is() {
    local name="$1"
    local type
    type=$(declare -p "$name" 2>/dev/null | awk '{print $2}' | tr -d '-')
    echo "Variable '$name':" >&2
    echo "  Declare flags: $type" >&2
    echo "  Value: ${!name@Q}" >&2  # @Q gives quoted/safe representation
}

# Check if command substitution returns empty
debug_cmd() {
    local result
    result=$("$@")
    echo "CMD: $*" >&2
    echo "RESULT: ${result:-<empty>}" >&2
    echo "EXIT: $?" >&2
    echo "$result"
}
```

---

## 8. Subshell and External Script Debugging

```bash
# Debug a script from the outside (without modifying it)
bash -x script.sh arg1 arg2

# Trace + errors
bash -xeuo pipefail script.sh

# Debug with custom PS4 without modifying the script
PS4='+${BASH_SOURCE[0]}:${LINENO}: ' bash -x script.sh

# Check syntax only (no execution)
bash -n script.sh && echo "Syntax OK"

# Dry-run a script (if it supports DRY_RUN env var)
DRY_RUN=true bash script.sh

# Trace a specific function in a sourced script
source ./lib.sh   # Source the library
set -x
my_library_function "test_arg"
set +x

# POSIX sh debugging (for scripts targeting /bin/sh)
sh -x script.sh
```

---

## 9. bashdb (Interactive Bash Debugger)

```bash
# Install: apt install bashdb / brew install bashdb
# Or: https://bashdb.sourceforge.net/

# Run script under bashdb
bashdb script.sh arg1 arg2

# bashdb commands:
# l           - list source code (current position)
# n           - next (step over)
# s           - step (step into)
# c           - continue
# b 42        - set breakpoint at line 42
# b myfunc    - set breakpoint at function entry
# p $var      - print variable
# p $(ls)     - evaluate expression
# bt          - backtrace (call stack)
# info variables - list all variables
# watch $var  - watchpoint
# q           - quit

# Pro tip: bashdb is rarely installed; use the debug_break() function above
# as a portable alternative that requires no installation.
```

---

## 10. Complete Debug Library

Drop this at the top of any script (or source from a library file):

```bash
#!/bin/bash
# debug-lib.sh — Complete debug/trace library
# Source: source "$(dirname "$0")/debug-lib.sh"

# ─── Configuration ─────────────────────────────────────────────────────────────
DEBUG="${DEBUG:-false}"     # Set to "true" or "1" to enable debug output
TRACE="${TRACE:-0}"         # Set to "1" to enable set -x tracing
_TRACE_FD=""
_TRACE_LOG="/tmp/trace-$$.log"

# ─── enable_debug ──────────────────────────────────────────────────────────────
enable_debug() {
    DEBUG=true
    TRACE=1

    # Custom PS4 with timestamp and location
    export PS4='+ [${EPOCHREALTIME}] ${BASH_SOURCE[0]##*/}:${FUNCNAME[0]:-main}:${LINENO}: '

    # Optionally redirect trace to file
    if [[ "${DEBUG_TO_FILE:-false}" == "true" ]]; then
        exec 9>"$_TRACE_LOG"
        export BASH_XTRACEFD=9
        echo "Trace output: $_TRACE_LOG" >&2
    fi

    set -x
    echo "[DEBUG] Debug mode enabled" >&2
}

# ─── disable_debug ─────────────────────────────────────────────────────────────
disable_debug() {
    set +x
    DEBUG=false

    if [[ -n "${_TRACE_FD:-}" ]]; then
        eval "exec ${_TRACE_FD}>&-"
        unset BASH_XTRACEFD
    fi

    echo "[DEBUG] Debug mode disabled" >&2
}

# ─── stack_trace ───────────────────────────────────────────────────────────────
stack_trace() {
    local start="${1:-1}"    # Skip this many frames from top
    local label="${2:-Stack Trace}"

    echo "─── $label ──────────────────────────────────" >&2
    local i
    for (( i=start; i<${#FUNCNAME[@]}; i++ )); do
        local func="${FUNCNAME[$i]:-main}"
        local src="${BASH_SOURCE[$i]:-unknown}"
        local line="${BASH_LINENO[$((i-1))]:-0}"
        printf '  [%d] %s()  at  %s:%d\n' "$((i-start))" "$func" "${src##*/}" "$line" >&2
    done
    echo "────────────────────────────────────────────" >&2
}

# ─── ERR trap setup ────────────────────────────────────────────────────────────
setup_error_trap() {
    trap '_debug_on_error' ERR
}

_debug_on_error() {
    local rc=$?
    echo "" >&2
    echo "ERROR: exit code $rc from: $BASH_COMMAND" >&2
    stack_trace 2 "Error Context"
    echo "" >&2
}

# ─── debug_break ───────────────────────────────────────────────────────────────
debug_break() {
    local label="${1:-BREAKPOINT}"
    [[ -t 0 ]] || { echo "[BREAK:$label] (non-interactive, continuing)" >&2; return; }

    echo "" >&2
    echo "╔══ BREAKPOINT: $label ══════════════════════" >&2
    echo "║ ${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}" >&2
    echo "╚══ Type 'c' continue │ 'q' quit │ expression to eval" >&2

    while IFS= read -r -p "(debug) " cmd </dev/tty; do
        case "$cmd" in
            ""|c|cont|continue)
                break
                ;;
            q|quit|exit)
                echo "Exiting at breakpoint: $label" >&2
                exit 1
                ;;
            bt|backtrace|stack)
                stack_trace 2
                ;;
            vars)
                declare -p | grep -v '^declare -[fx]' | head -40 >&2
                ;;
            *)
                eval "$cmd" 2>&1 >&2 || true
                ;;
        esac
    done
    echo "(continuing)" >&2
}

# ─── Auto-initialize ───────────────────────────────────────────────────────────
if [[ "${TRACE:-0}" == "1" ]] || [[ "${DEBUG:-false}" == "true" ]]; then
    enable_debug
fi

if [[ "${DEBUG_TRAPS:-false}" == "true" ]]; then
    setup_error_trap
fi
```

### Usage Examples

```bash
# Enable full tracing for this run:
TRACE=1 ./script.sh

# Enable debug traps only:
DEBUG_TRAPS=true ./script.sh

# Send trace to file:
DEBUG_TO_FILE=true TRACE=1 ./script.sh
# Then: cat /tmp/trace-<pid>.log

# In script: use breakpoints
source debug-lib.sh
setup_error_trap

complex_function() {
    debug_break "Before heavy computation"
    result=$(expensive_operation)
    debug_break "After heavy computation (result=$result)"
    echo "$result"
}

# Selectively trace a section
debug_start
  tricky_code
debug_stop
```
