# Argument Parsing in Shell Scripts

Comprehensive guide to getopts, getopt, subcommand routing, and validation patterns.

---

## 1. getopts — POSIX Built-in Short Options

`getopts` is the portable, built-in approach for parsing short options (`-v`, `-o file`).

### Basic Loop Structure

```bash
#!/bin/bash
set -Eeuo pipefail

VERBOSE=false
OUTPUT=""
COUNT=1

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [ARGS...]

Options:
    -v          Enable verbose output
    -o FILE     Output file (required)
    -n COUNT    Number of iterations (default: 1)
    -h          Show this help

Examples:
    $(basename "$0") -v -o result.txt input.txt
    $(basename "$0") -n 5 -o out.txt file1 file2
EOF
    exit "${1:-0}"
}

while getopts ":vo:n:h" opt; do
    case "$opt" in
        v) VERBOSE=true ;;
        o) OUTPUT="$OPTARG" ;;
        n) COUNT="$OPTARG" ;;
        h) usage 0 ;;
        :) echo "ERROR: Option -$OPTARG requires an argument" >&2; usage 1 ;;
        ?) echo "ERROR: Unknown option: -$OPTARG" >&2; usage 1 ;;
    esac
done
shift $((OPTIND - 1))   # Shift past parsed options; $@ now has positional args

# Validate required options
[[ -n "$OUTPUT" ]] || { echo "ERROR: -o FILE is required" >&2; usage 1; }

# Validate numeric argument
[[ "$COUNT" =~ ^[0-9]+$ ]] || { echo "ERROR: -n must be a positive integer" >&2; exit 1; }
```

### OPTIND and OPTARG Mechanics

| Variable | Meaning |
|----------|---------|
| `OPTIND` | Index of the NEXT argument to process. Starts at 1. After the loop, `shift $((OPTIND-1))` removes all parsed options from `$@`. |
| `OPTARG` | Value of the option argument (set when option has `:` in optstring). |
| `OPTERR` | Set to 0 to suppress getopts's own error messages (silent error handling). |

### Error Handling: `:` vs `?`

The optstring starts with `:` to enable **silent error mode**:

```bash
# Silent mode (optstring starts with :) — YOU handle errors
while getopts ":abc:" opt; do
    case "$opt" in
        :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;   # missing arg
        ?) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;               # bad flag
    esac
done

# Verbose mode (no leading :) — getopts prints errors itself
while getopts "abc:" opt; do
    # getopts prints: "illegal option -- X" and "option requires an argument -- c"
    # ? catches unknown options, but getopts already printed the message
    case "$opt" in
        ?) exit 1 ;;
    esac
done
```

**Always use silent mode** (leading `:`) in production — gives you control over error messages.

### Resetting getopts for Function Reuse

```bash
# getopts is NOT re-entrant by default; reset OPTIND to parse again
parse_opts() {
    local OPTIND=1    # local OPTIND makes getopts reentrant inside functions
    local verbose=false
    while getopts ":v" opt; do
        case "$opt" in
            v) verbose=true ;;
        esac
    done
    shift $((OPTIND - 1))
    echo "verbose=$verbose, remaining: $*"
}

parse_opts -v foo bar   # verbose=true, remaining: foo bar
parse_opts foo bar      # verbose=false, remaining: foo bar
```

---

## 2. getopt — GNU Long Options

`getopt` (external command, not built-in) supports long options like `--verbose` and `--output=file`.

### Basic Long Option Parsing

```bash
#!/bin/bash
set -Eeuo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] FILES...

Options:
    -v, --verbose           Enable verbose output
    -o, --output FILE       Output file
    -n, --count N           Iteration count (default: 1)
    -d, --dry-run           Show what would be done
    -h, --help              Show this help
EOF
    exit "${1:-0}"
}

# Check getopt version supports long options
getopt --test &>/dev/null
[[ $? -ne 4 ]] && { echo "ERROR: GNU getopt required" >&2; exit 1; }

OPTS=$(getopt \
    --options vn:o:dh \
    --longoptions verbose,count:,output:,dry-run,help \
    --name "$(basename "$0")" \
    -- "$@") || { usage 1; }

eval set -- "$OPTS"

VERBOSE=false
OUTPUT=""
COUNT=1
DRY_RUN=false

while true; do
    case "$1" in
        -v|--verbose)   VERBOSE=true;   shift ;;
        -o|--output)    OUTPUT="$2";    shift 2 ;;
        -n|--count)     COUNT="$2";     shift 2 ;;
        -d|--dry-run)   DRY_RUN=true;   shift ;;
        -h|--help)      usage 0 ;;
        --)             shift; break ;;
        *)              echo "ERROR: unexpected option $1" >&2; exit 1 ;;
    esac
done

# $@ now contains positional arguments after --
FILES=("$@")
```

### Optional Arguments with getopt

```bash
# Optional arg: use :: (double colon) in optstring
OPTS=$(getopt --options "v::o:" --longoptions "verbose::,output:" -- "$@")
eval set -- "$OPTS"

while true; do
    case "$1" in
        -v|--verbose)
            # Optional args come as empty string if not provided
            VERBOSITY="${2:-1}"
            shift 2
            ;;
        -o|--output) OUTPUT="$2"; shift 2 ;;
        --) shift; break ;;
    esac
done
# Usage: script -v      # VERBOSITY=1
#        script -v3     # VERBOSITY=3
#        script --verbose=5  # VERBOSITY=5
```

---

## 3. Subcommand Routing (git-style)

For complex tools with multiple subcommands (`script deploy`, `script rollback`, etc.).

```bash
#!/bin/bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

PROGRAM=$(basename "$0")

usage_main() {
    cat <<EOF
Usage: $PROGRAM <command> [options]

Commands:
    deploy      Deploy application to environment
    rollback    Rollback to previous version
    status      Show deployment status
    logs        Tail application logs

Run '$PROGRAM <command> --help' for command-specific help.
EOF
    exit "${1:-0}"
}

cmd_deploy() {
    local env="" force=false
    while getopts ":e:fh" opt; do
        case "$opt" in
            e) env="$OPTARG" ;;
            f) force=true ;;
            h) echo "Usage: $PROGRAM deploy -e ENV [-f]"; exit 0 ;;
            :) echo "ERROR: -$OPTARG requires argument" >&2; exit 1 ;;
            ?) echo "ERROR: unknown option -$OPTARG" >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))
    [[ -n "$env" ]] || { echo "ERROR: -e ENV required" >&2; exit 1; }
    echo "Deploying to $env (force=$force)"
}

cmd_rollback() {
    local version=""
    while getopts ":v:h" opt; do
        case "$opt" in
            v) version="$OPTARG" ;;
            h) echo "Usage: $PROGRAM rollback [-v VERSION]"; exit 0 ;;
            :) echo "ERROR: -$OPTARG requires argument" >&2; exit 1 ;;
            ?) echo "ERROR: unknown option -$OPTARG" >&2; exit 1 ;;
        esac
    done
    echo "Rolling back to ${version:-previous}"
}

cmd_status() { echo "Status: running"; }
cmd_logs()   { tail -f /var/log/app.log; }

# Route to subcommand
[[ $# -gt 0 ]] || usage_main 1
COMMAND="$1"; shift

case "$COMMAND" in
    deploy)     cmd_deploy   "$@" ;;
    rollback)   cmd_rollback "$@" ;;
    status)     cmd_status   "$@" ;;
    logs)       cmd_logs     "$@" ;;
    -h|--help)  usage_main 0 ;;
    *)          echo "ERROR: unknown command: $COMMAND" >&2; usage_main 1 ;;
esac
```

### Dispatch via Function Name Convention

```bash
# Automatically dispatch to cmd_<subcommand> functions
COMMAND="${1:-help}"; shift || true

if declare -f "cmd_$COMMAND" > /dev/null 2>&1; then
    "cmd_$COMMAND" "$@"
else
    echo "ERROR: unknown command: $COMMAND" >&2
    usage_main 1
fi
```

---

## 4. Argument Validation Patterns

```bash
# Type checking helpers
is_integer()    { [[ "$1" =~ ^-?[0-9]+$ ]]; }
is_pos_integer(){ [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]; }
is_float()      { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }
is_ipv4()       { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }
is_url()        { [[ "$1" =~ ^https?:// ]]; }
is_email()      { [[ "$1" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; }

# Range checking
validate_port() {
    local port="$1"
    is_pos_integer "$port" && [[ "$port" -le 65535 ]] || {
        echo "ERROR: invalid port: $port (must be 1-65535)" >&2
        return 1
    }
}

# Enum validation
validate_env() {
    local env="$1"
    local valid_envs=("dev" "staging" "prod")
    local e
    for e in "${valid_envs[@]}"; do
        [[ "$env" == "$e" ]] && return 0
    done
    echo "ERROR: invalid env '$env'. Valid: ${valid_envs[*]}" >&2
    return 1
}

# File/dir validation
validate_file() {
    local path="$1" label="${2:-file}"
    [[ -f "$path" ]] || { echo "ERROR: $label not found: $path" >&2; return 1; }
    [[ -r "$path" ]] || { echo "ERROR: $label not readable: $path" >&2; return 1; }
}

validate_dir() {
    local path="$1" label="${2:-directory}"
    [[ -d "$path" ]] || { echo "ERROR: $label not found: $path" >&2; return 1; }
    [[ -w "$path" ]] || { echo "ERROR: $label not writable: $path" >&2; return 1; }
}

# Usage in script
validate_port "$PORT"
validate_env  "$ENVIRONMENT"
validate_file "$CONFIG_FILE" "config"
```

---

## 5. Help Text Generation

```bash
# Aligned help with automatic column detection
print_option() {
    local short="$1" long="$2" arg="$3" desc="$4"
    printf "    %-4s %-20s %s\n" "$short" "$long" "$desc"
}

usage() {
    echo "Usage: $(basename "$0") [OPTIONS] SOURCE DEST"
    echo ""
    echo "Transfer files from SOURCE to DEST."
    echo ""
    echo "Options:"
    print_option "-v," "--verbose"           ""        "Enable verbose output"
    print_option "-n," "--dry-run"           ""        "Show actions without executing"
    print_option "-e," "--env ENV"           "ENV"     "Target environment (dev|staging|prod)"
    print_option "-p," "--port PORT"         "PORT"    "Server port (default: 8080)"
    print_option "-c," "--config FILE"       "FILE"    "Config file (default: ./config.yml)"
    print_option "-h," "--help"              ""        "Show this help"
    echo ""
    echo "Environment Variables:"
    printf "    %-25s %s\n" "APP_ENV"        "Same as --env"
    printf "    %-25s %s\n" "APP_PORT"       "Same as --port"
    printf "    %-25s %s\n" "APP_CONFIG"     "Same as --config"
    echo ""
    echo "Examples:"
    echo "    $(basename "$0") -e prod -p 443 /local/path /remote/path"
    echo "    $(basename "$0") --dry-run --verbose source/ dest/"
    exit "${1:-0}"
}
```

---

## 6. Hybrid Positional + Optional Arguments

```bash
#!/bin/bash
set -Eeuo pipefail

# Script accepts: script [OPTIONS] COMMAND [ARGS...]
# Where COMMAND and ARGS are positional, OPTIONS are flags

VERBOSE=false
CONFIG="${HOME}/.config/app/config.yml"

while getopts ":vc:h" opt; do
    case "$opt" in
        v) VERBOSE=true ;;
        c) CONFIG="$OPTARG" ;;
        h) usage 0 ;;
        :) echo "ERROR: -$OPTARG requires argument" >&2; exit 1 ;;
        ?) echo "ERROR: unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Now positional args
[[ $# -ge 1 ]] || { echo "ERROR: COMMAND required" >&2; usage 1; }

COMMAND="$1"; shift
REMAINING_ARGS=("$@")   # Everything after COMMAND

$VERBOSE && echo "Config: $CONFIG, Command: $COMMAND, Args: ${REMAINING_ARGS[*]:-}" >&2

# Handle -- separator: allows passing flags to subcommand
# script -v -- --some-flag-for-subcommand
# After the loop's shift $((OPTIND-1)), "--" is consumed, so $@ has subcommand flags
```

---

## 7. Environment Variable Fallback Pattern

```bash
# Prefer CLI args, fall back to env vars, then defaults
OPTS=$(getopt --options "e:p:c:h" --longoptions "env:,port:,config:,help" --name "$0" -- "$@")
eval set -- "$OPTS"

# Defaults from environment (or hardcoded)
ENV="${APP_ENV:-dev}"
PORT="${APP_PORT:-8080}"
CONFIG="${APP_CONFIG:-./config.yml}"

while true; do
    case "$1" in
        -e|--env)    ENV="$2";    shift 2 ;;
        -p|--port)   PORT="$2";   shift 2 ;;
        -c|--config) CONFIG="$2"; shift 2 ;;
        -h|--help)   usage 0 ;;
        --)          shift; break ;;
    esac
done

echo "Running: env=$ENV port=$PORT config=$CONFIG"
```

---

## Decision Matrix: getopts vs getopt vs manual case

| Scenario | Recommendation |
|----------|---------------|
| Short options only (`-v`, `-o FILE`) | `getopts` — portable, built-in |
| Long options needed (`--verbose`) | `getopt` (GNU) — requires GNU coreutils |
| Complex subcommands | Manual `case "$1"` routing |
| POSIX portability (sh, dash) | `getopts` — only portable option |
| Optional arguments (`-v3` or just `-v`) | `getopt` with `::` optstring |
| Mixing long and short | `getopt` — cleaner than manual |
