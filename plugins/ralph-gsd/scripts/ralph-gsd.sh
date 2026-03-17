#!/usr/bin/env bash
#
# ralph-gsd.sh - Autonomous Milestone Execution Orchestrator
#
# Combines the Ralph Wiggum technique with GSD workflow to autonomously
# execute entire milestones. Works with any project that has GSD state.
#
# Usage:
#   ralph-gsd.sh --project-dir /path/to/project [options]
#
# Options:
#   --project-dir PATH    Project directory with .planning/ (required)
#   --max-iterations N    Safety limit (default: 100)
#   --skip-discuss        Auto-skip discuss phase with defaults
#   --max-parallel N      Max concurrent Claude sessions (default: 4)
#   --dry-run             Show what would happen without executing
#   --stop-file PATH      External STOP file to check each iteration
#   --resume              Skip phases already verified in STATE.md
#   --log-file PATH       Redirect log output to this path
#   --help                Show this help message
#
# Exit Codes:
#   0 = complete (all phases verified)
#   1 = error (unrecoverable failure)
#   2 = stopped (STOP file detected, graceful shutdown)
#   3 = deadlock (no phases can make progress)
#
# Author: George (via Claude)
# License: MIT

set -euo pipefail

# Source cost tracker if available
[[ -f "$HOME/.claude/scripts/cost-tracker.sh" ]] && source "$HOME/.claude/scripts/cost-tracker.sh"

#=============================================================================
# Configuration
#=============================================================================

VERSION="2.0.0"
DEFAULT_MAX_ITERATIONS=100
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE=""
PROJECT_DIR=""
MAX_ITERATIONS=$DEFAULT_MAX_ITERATIONS
SKIP_DISCUSS=false
DRY_RUN=false
RESUME=false
STOP_FILE_EXTERNAL=""
ITERATION=0
PHASE_TIMEOUT="${PHASE_TIMEOUT:-1800}"
SKIP_EVALUATOR=false

# Exit code constants
EXIT_COMPLETE=0
EXIT_ERROR=1
EXIT_STOPPED=2
EXIT_DEADLOCK=3

# Tracks how we exited for the machine-readable summary
RALPH_EXIT_CODE=$EXIT_COMPLETE
RALPH_CURRENT_PHASE="none"

# Parallel execution globals
declare -A PHASE_DEPS          # phase → space-separated dependency phase numbers
declare -A PHASE_STUCK_COUNT   # per-phase stuck detection counter
declare -A PHASE_LAST_ACTION   # per-phase last action tracking
declare -A PHASE_SKIPPED       # phases marked as stuck/skipped
PARALLEL_LOG_DIR=""
MAX_PARALLEL=4                 # max concurrent claude sessions

#=============================================================================
# Colors and Output
#=============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    [[ -n "$LOG_FILE" ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    [[ -n "$LOG_FILE" ]] && echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    [[ -n "$LOG_FILE" ]] && echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    [[ -n "$LOG_FILE" ]] && echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

log_phase() {
    echo -e "${CYAN}[PHASE]${NC} $*"
    [[ -n "$LOG_FILE" ]] && echo "[PHASE] $(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

#=============================================================================
# Stop File and Exit Handling
#=============================================================================

# Check if a STOP file exists (internal or external)
# Returns 0 (true) if stop is requested, 1 (false) otherwise
is_stop_requested() {
    local internal_stop="$PROJECT_DIR/.planning/RALPH_STOP"

    if [[ -f "$internal_stop" ]]; then
        log_warn "Internal STOP file detected: $internal_stop"
        return 0
    fi

    if [[ -n "$STOP_FILE_EXTERNAL" ]] && [[ -f "$STOP_FILE_EXTERNAL" ]]; then
        log_warn "External STOP file detected: $STOP_FILE_EXTERNAL"
        return 0
    fi

    return 1
}

# Remove stop files after graceful shutdown
cleanup_stop_files() {
    local internal_stop="$PROJECT_DIR/.planning/RALPH_STOP"
    [[ -f "$internal_stop" ]] && rm -f "$internal_stop" && log_info "Removed internal STOP file"
    if [[ -n "$STOP_FILE_EXTERNAL" ]] && [[ -f "$STOP_FILE_EXTERNAL" ]]; then
        rm -f "$STOP_FILE_EXTERNAL"
        log_info "Removed external STOP file: $STOP_FILE_EXTERNAL"
    fi
}

# Print machine-readable exit summary and exit with the given code
ralph_exit() {
    local code=$1
    local phases_complete=${2:-0}
    local phases_total=${3:-0}
    local current_phase=${4:-"none"}

    echo "RALPH_EXIT: code=$code phases_complete=$phases_complete phases_total=$phases_total current_phase=$current_phase"
    exit "$code"
}

#=============================================================================
# Help and Version
#=============================================================================

show_help() {
    cat << 'EOF'
ralph-gsd.sh - Autonomous Milestone Execution Orchestrator

USAGE:
    ralph-gsd.sh --project-dir PATH [options]

REQUIRED:
    --project-dir PATH    Project directory containing .planning/

OPTIONS:
    --max-iterations N    Maximum iterations before stopping (default: 100)
    --skip-discuss        Auto-skip discuss phase using sensible defaults
    --max-parallel N      Maximum concurrent Claude sessions (default: 4)
    --dry-run             Show planned actions without executing
    --stop-file PATH      External STOP file to check each iteration (in addition
                          to the internal .planning/RALPH_STOP file). Either file
                          triggers graceful shutdown with exit code 2.
    --resume              Skip phases that are already verified. Useful for
                          restarting after a stop without re-running completed work.
    --log-file PATH       Redirect log output to this path instead of the default
                          .planning/ralph-gsd.log
    --phase-timeout N     Seconds before a single claude invocation is killed
                          (default: 1800). Also honoured via PHASE_TIMEOUT env var.
    --skip-evaluator      Skip the post-milestone code-quality evaluator pass
    --help                Show this help message
    --version             Show version information

EXIT CODES:
    0   Complete — all phases verified successfully
    1   Error — unrecoverable failure
    2   Stopped — STOP file detected, graceful shutdown after current phase
    3   Deadlock — phases remain but none have dependencies met

MACHINE-READABLE OUTPUT:
    On exit, ralph-gsd prints a summary line to stdout:
        RALPH_EXIT: code=N phases_complete=X phases_total=Y current_phase=Z

STOP FILE:
    Create .planning/RALPH_STOP (or the path given via --stop-file) to request a
    graceful stop. Ralph finishes the current in-progress phase, then exits with
    code 2. The STOP file is removed automatically on graceful shutdown so that a
    subsequent --resume run can proceed cleanly.

DESCRIPTION:
    Ralph-GSD orchestrates the GSD workflow autonomously. After creating a
    milestone with /gsd:new-project or /gsd:new-milestone, start Ralph to
    work through all phases without manual intervention.

    Ralph reads the .planning/ state files to determine:
    - Current milestone progress
    - Which phase needs attention
    - What GSD command to run next

    Checkpoint Handling:
    - checkpoint:human-verify → Logged to DEFERRED.md, continues
    - checkpoint:decision → Makes sensible default choice, continues
    - checkpoint:human-action → Logged and skipped, continues

    Parallel Execution:
    - Parses phase dependencies from ROADMAP.md
    - Executes independent phases in parallel (up to --max-parallel)
    - Sequential execution when only one phase is ready
    - Per-phase stuck detection with graceful continuation

WORKFLOW:
    1. Create milestone: claude > /gsd:new-project "My Feature"
    2. Start Ralph: ralph-gsd.sh --project-dir .
    3. Ralph executes: discuss → plan → execute → verify (per phase)
    4. Review deferred: cat .planning/DEFERRED.md

FILES:
    .planning/STATE.md       Current milestone state
    .planning/ROADMAP.md     Phase definitions
    .planning/DEFERRED.md    Skipped checkpoints for review
    .planning/RALPH_STOP     Create this file to request graceful shutdown

EXAMPLES:
    # Execute milestone with default settings
    ralph-gsd.sh --project-dir ~/projects/myapp

    # Limit iterations and skip discuss phases
    ralph-gsd.sh --project-dir . --max-iterations 50 --skip-discuss

    # Preview what would happen
    ralph-gsd.sh --project-dir . --dry-run

    # Run with 8 parallel sessions
    ralph-gsd.sh --project-dir . --max-parallel 8

    # Resume after a previous stop (skip already-verified phases)
    ralph-gsd.sh --project-dir . --resume

    # Integrate with an autopilot controller that manages the STOP file
    ralph-gsd.sh --project-dir . --stop-file .autopilot/STOP --log-file .autopilot/ralph.log

EOF
}

show_version() {
    echo "ralph-gsd.sh version $VERSION"
}

#=============================================================================
# Argument Parsing
#=============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-dir)
                PROJECT_DIR="$2"
                shift 2
                ;;
            --max-iterations)
                MAX_ITERATIONS="$2"
                shift 2
                ;;
            --skip-discuss)
                SKIP_DISCUSS=true
                shift
                ;;
            --max-parallel)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --stop-file)
                STOP_FILE_EXTERNAL="$2"
                shift 2
                ;;
            --resume)
                RESUME=true
                shift
                ;;
            --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            --phase-timeout)
                PHASE_TIMEOUT="$2"
                shift 2
                ;;
            --skip-evaluator)
                SKIP_EVALUATOR=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$PROJECT_DIR" ]]; then
        log_error "Missing required argument: --project-dir"
        echo "Use --help for usage information"
        exit 1
    fi

    # Resolve to absolute path
    PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
        log_error "Project directory does not exist: $PROJECT_DIR"
        exit 1
    }

    # Check for .planning directory
    if [[ ! -d "$PROJECT_DIR/.planning" ]]; then
        log_error "No .planning directory found in $PROJECT_DIR"
        log_error "Run /gsd:new-project or /gsd:new-milestone first"
        exit 1
    fi

    # Set up log file (only if not provided via --log-file)
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="$PROJECT_DIR/.planning/ralph-gsd.log"
    fi
}

#=============================================================================
# State Detection
#=============================================================================

# Get list of phases from ROADMAP.md
# Only returns phases that are NOT already marked complete with [x] checkboxes
get_phases() {
    local roadmap="$PROJECT_DIR/.planning/ROADMAP.md"

    if [[ ! -f "$roadmap" ]]; then
        log_error "ROADMAP.md not found"
        return 1
    fi

    # Extract completed phase numbers: lines like "- [x] Phase N:" or "- [x] Phase N "
    local completed_phases
    completed_phases=$(grep -oE '^\- \[x\] Phase [0-9]+' "$roadmap" | grep -oE '[0-9]+' | sort -u -n)

    # Extract ALL phase numbers from section headers (## Phase N or ### Phase N)
    # These are the authoritative phase definitions (not the checkbox summary list)
    local all_phases
    all_phases=$(grep -oE '^#{2,}[[:space:]]*Phase[[:space:]]+[0-9]+' "$roadmap" | grep -oE '[0-9]+' | sort -u -n)

    # Return only phases not in the completed set
    for phase in $all_phases; do
        if ! echo "$completed_phases" | grep -qx "$phase"; then
            echo "$phase"
        fi
    done
}

# Get status of a specific phase
# Returns: not_started|context_captured|planned|partially_executed|executed|verified|gaps
get_phase_status() {
    local phase=$1
    local state_file="$PROJECT_DIR/.planning/STATE.md"
    local phase_dir="$PROJECT_DIR/.planning/phases"

    # First check STATE.md for completion status
    if [[ -f "$state_file" ]]; then
        # Look for phase status in the Progress table
        # Match patterns like "| 1. Photo Saving | Completed |" or "| 6. ... | Not Started |"
        if grep -E "^\|[[:space:]]*$phase\.[[:space:]].*\|[[:space:]]*Completed[[:space:]]*\|" "$state_file" >/dev/null 2>&1; then
            echo "verified"
            return
        fi
    fi

    # Format phase number with leading zero
    local phase_padded=$(printf "%02d" "$phase")

    # Find phase directory - could be exact match (06) or with suffix (06-name)
    local phase_path=""

    # Try exact padded match first
    if [[ -d "$phase_dir/$phase_padded" ]]; then
        phase_path="$phase_dir/$phase_padded"
    # Try exact unpadded match
    elif [[ -d "$phase_dir/$phase" ]]; then
        phase_path="$phase_dir/$phase"
    else
        # Try glob match for directories starting with phase number
        local found_dir
        found_dir=$(find "$phase_dir" -maxdepth 1 -type d -name "${phase_padded}-*" 2>/dev/null | head -1)
        if [[ -n "$found_dir" && -d "$found_dir" ]]; then
            phase_path="$found_dir"
        else
            # Try without padding
            found_dir=$(find "$phase_dir" -maxdepth 1 -type d -name "${phase}-*" 2>/dev/null | head -1)
            if [[ -n "$found_dir" && -d "$found_dir" ]]; then
                phase_path="$found_dir"
            else
                echo "not_started"
                return
            fi
        fi
    fi

    # Check for VERIFICATION.md with success - also check for numbered variants like 04-VERIFICATION.md
    local verification_file=""
    if [[ -f "$phase_path/VERIFICATION.md" ]]; then
        verification_file="$phase_path/VERIFICATION.md"
    else
        verification_file=$(find "$phase_path" -maxdepth 1 -name "*VERIFICATION.md" 2>/dev/null | head -1)
    fi

    if [[ -n "$verification_file" && -f "$verification_file" ]]; then
        if grep -qi "VERIFIED\|PASSED\|SUCCESS\|ALL.*COMPLETE" "$verification_file" 2>/dev/null; then
            echo "verified"
            return
        else
            # Verification exists but has gaps
            echo "gaps"
            return
        fi
    fi

    # Count PLAN and SUMMARY files to detect partial execution
    local plan_count summary_count
    plan_count=$(find "$phase_path" -maxdepth 1 -name "*-PLAN.md" -o -name "*PLAN.md" 2>/dev/null | wc -l)
    summary_count=$(find "$phase_path" -maxdepth 1 -name "*-SUMMARY.md" -o -name "*SUMMARY.md" 2>/dev/null | wc -l)

    if [[ $plan_count -gt 0 && $summary_count -ge $plan_count ]]; then
        # All plans have summaries - fully executed
        echo "executed"
        return
    fi

    if [[ $plan_count -gt 0 && $summary_count -gt 0 ]]; then
        # Some plans executed, some still pending
        echo "partially_executed"
        return
    fi

    if [[ $plan_count -gt 0 ]]; then
        # Plans exist but none executed yet
        echo "planned"
        return
    fi

    # Check for CONTEXT.md or DISCUSSION.md (discuss complete)
    if [[ -f "$phase_path/CONTEXT.md" ]] || [[ -f "$phase_path/DISCUSSION.md" ]]; then
        echo "context_captured"
        return
    fi

    # Check for RESEARCH.md (research done, ready for planning) - also check for numbered variants
    if compgen -G "$phase_path/*RESEARCH.md" > /dev/null 2>&1; then
        echo "context_captured"
        return
    fi

    echo "not_started"
}

# Find the current phase to work on
get_current_phase() {
    local phases
    phases=$(get_phases) || {
        echo "ERROR"
        return 0
    }

    if [[ -z "$phases" ]]; then
        echo "ERROR"
        return 0
    fi

    for phase in $phases; do
        local status
        status=$(get_phase_status "$phase")

        if [[ "$status" != "verified" ]]; then
            echo "$phase"
            return 0
        fi
    done

    # All phases verified
    echo "COMPLETE"
}

# Check if milestone is complete
is_milestone_complete() {
    local current
    current=$(get_current_phase)
    [[ "$current" == "COMPLETE" ]]
}

#=============================================================================
# Action Mapping
#=============================================================================

# Determine the next GSD command to run
determine_next_action() {
    local phase=$1
    local status
    status=$(get_phase_status "$phase")

    case $status in
        not_started)
            if [[ "$SKIP_DISCUSS" == true ]]; then
                echo "plan-phase $phase"
            else
                echo "discuss-phase $phase"
            fi
            ;;
        context_captured)
            echo "plan-phase $phase"
            ;;
        planned)
            echo "execute-phase $phase"
            ;;
        partially_executed)
            echo "execute-phase $phase"
            ;;
        executed)
            echo "verify-work $phase"
            ;;
        gaps)
            echo "plan-phase $phase --gaps"
            ;;
        verified)
            echo "NEXT_PHASE"
            ;;
        *)
            log_error "Unknown status: $status"
            echo "ERROR"
            ;;
    esac
}

#=============================================================================
# Prompt Building
#=============================================================================

# Build the autonomous mode prompt injection
build_autonomous_prompt() {
    cat << 'PROMPT'
## RALPH AUTONOMOUS MODE

You are running in autonomous mode within the Ralph-GSD orchestrator.

### Discuss Phase (Auto-Answer Mode)

When running `/gsd:discuss-phase`, answer all questions with sensible defaults:
- Choose the most common/standard approach
- Prefer simplicity over complexity
- Use mainstream technologies (React, Tailwind, TypeScript, etc.)
- Log all auto-decisions: "AUTO-DISCUSS: [question] -> [choice] because [reason]"
- Create CONTEXT.md with these choices documented

### Checkpoint Handling Rules

1. **checkpoint:human-verify** - Log to DEFERRED.md and CONTINUE:
   - Note: "DEFERRED: Visual verification needed for [description]"
   - Do NOT stop execution
   - Assume the work is correct and proceed

2. **checkpoint:decision** - Make the BEST decision autonomously:
   - Choose the most sensible/common option
   - Log: "AUTO-DECIDED: Chose [option] for [decision] because [reason]"
   - Continue execution

3. **checkpoint:human-action** - Log and SKIP:
   - Note: "DEFERRED: Manual action needed - [description]"
   - Continue with next task
   - The action will be performed at milestone end

### State File Updates

After each significant action, update:
- `.planning/STATE.md` - Current position
- `.planning/DEFERRED.md` - Add any skipped items

### Completion Signal

When the current GSD command completes successfully, output:
```
RALPH_STATUS: COMMAND_COMPLETE
```

If you hit an unrecoverable error:
```
RALPH_STATUS: ERROR
RALPH_ERROR: [description]
```
PROMPT
}

# Build the full prompt for Claude
build_prompt() {
    local gsd_command=$1

    cat << EOF
$(build_autonomous_prompt)

---

## Current Task

Run the following GSD command:

/gsd:$gsd_command

Work autonomously. Do not ask for human input. Make sensible default choices.
Log any skipped checkpoints to .planning/DEFERRED.md.

When complete, output: RALPH_STATUS: COMMAND_COMPLETE
EOF
}

#=============================================================================
# Deferred Items Management
#=============================================================================

# Initialize DEFERRED.md if it doesn't exist
init_deferred() {
    local deferred_file="$PROJECT_DIR/.planning/DEFERRED.md"

    if [[ ! -f "$deferred_file" ]]; then
        cat > "$deferred_file" << 'EOF'
# Deferred Items

Items logged by Ralph-GSD and processed autonomously after milestone completion. No human involvement required — all items are resolved by `process_deferred_items()` using browser agents, fix agents, and code agents.

---

EOF
        log_info "Created DEFERRED.md"
    fi
}

# Log a deferred item
log_deferred() {
    local item=$1
    local phase=${2:-"unknown"}
    local deferred_file="$PROJECT_DIR/.planning/DEFERRED.md"

    init_deferred

    echo "- [ ] $item (phase $phase, iteration $ITERATION)" >> "$deferred_file"
    log_warn "Deferred: $item"
}

#=============================================================================
# Dependency Parsing and Parallel Execution
#=============================================================================

# Parse all phase dependencies from ROADMAP.md
parse_all_dependencies() {
    local roadmap="$PROJECT_DIR/.planning/ROADMAP.md"

    if [[ ! -f "$roadmap" ]]; then
        log_error "ROADMAP.md not found"
        return 1
    fi

    log_info "Parsing phase dependencies from ROADMAP.md"

    local current_phase=""
    while IFS= read -r line; do
        # Detect phase headers (## Phase NN or ### Phase NN)
        if [[ "$line" =~ ^##+[[:space:]]*Phase[[:space:]]+([0-9]+) ]]; then
            current_phase="${BASH_REMATCH[1]}"
            # Initialize with empty deps
            PHASE_DEPS["$current_phase"]=""
        fi

        # Look for dependency lines: **Depends on**: Phase 18 (v2.0 complete)
        if [[ -n "$current_phase" ]] && [[ "$line" =~ \*\*Depends[[:space:]]+on\*\*:[[:space:]]*(.*) ]]; then
            local deps_line="${BASH_REMATCH[1]}"
            # Extract all "Phase N" references (individual)
            local deps=""
            while [[ "$deps_line" =~ Phase[[:space:]]+([0-9]+) ]]; do
                deps="$deps ${BASH_REMATCH[1]}"
                deps_line="${deps_line#*Phase ${BASH_REMATCH[1]}}"
            done

            # Extract range syntax: "Phases X-Y" or "phases X-Y" or "Phase X-Y"
            # e.g. "Phases 13-18" → 13 14 15 16 17 18
            # Re-read from the original capture since deps_line was consumed above
            # Extract range syntax: "Phases X-Y" → expand to all integers X..Y
            local orig_deps_line=""
            if [[ "${line}" =~ \*\*Depends[[:space:]]+on\*\*:[[:space:]]*(.*) ]]; then
                orig_deps_line="${BASH_REMATCH[1]}"
            fi
            if [[ -n "$orig_deps_line" ]]; then
                while [[ "$orig_deps_line" =~ [Pp]hases?[[:space:]]+([0-9]+)-([0-9]+) ]]; do
                    local range_start="${BASH_REMATCH[1]}"
                    local range_end="${BASH_REMATCH[2]}"
                    local matched="${BASH_REMATCH[0]}"
                    for ((n = range_start; n <= range_end; n++)); do
                        if [[ ! " $deps " =~ " $n " ]]; then
                            deps="$deps $n"
                        fi
                    done
                    # Advance past this match to find additional ranges
                    orig_deps_line="${orig_deps_line#*${matched}}"
                done
            fi

            # Trim leading space
            deps="${deps# }"
            PHASE_DEPS["$current_phase"]="$deps"
            if [[ -n "$deps" ]]; then
                log_info "Phase $current_phase depends on: $deps"
            fi
        fi
    done < "$roadmap"

    log_success "Dependency parsing complete"
    return 0
}

# Get dependencies for a specific phase
get_phase_dependencies() {
    local phase=$1
    echo "${PHASE_DEPS[$phase]:-}"
}

# Check if all dependencies for a phase are met (verified)
are_dependencies_met() {
    local phase=$1
    local deps
    deps=$(get_phase_dependencies "$phase")

    if [[ -z "$deps" ]]; then
        # No dependencies - always ready
        return 0
    fi

    for dep in $deps; do
        local dep_status
        dep_status=$(get_phase_status "$dep")
        if [[ "$dep_status" != "verified" ]]; then
            return 1
        fi
    done

    return 0
}

# Get all phases that are ready to execute (dependencies met, not verified)
# Returns: space-separated phase numbers, "COMPLETE", or "DEADLOCK"
get_ready_phases() {
    local phases
    phases=$(get_phases) || {
        echo "ERROR"
        return 0
    }

    local ready_phases=""
    local all_verified=true
    local has_unverified=false

    for phase in $phases; do
        local status
        status=$(get_phase_status "$phase")

        if [[ "$status" == "verified" ]]; then
            continue
        fi

        has_unverified=true
        all_verified=false

        # Skip phases that have been marked as stuck
        if [[ -n "${PHASE_SKIPPED[$phase]:-}" ]]; then
            continue
        fi

        if are_dependencies_met "$phase"; then
            ready_phases="$ready_phases $phase"
        fi
    done

    # Trim leading space
    ready_phases="${ready_phases# }"

    if [[ "$all_verified" == true ]]; then
        echo "COMPLETE"
        return 0
    fi

    if [[ -z "$ready_phases" ]] && [[ "$has_unverified" == true ]]; then
        echo "DEADLOCK"
        return 0
    fi

    echo "$ready_phases"
}

# Per-phase stuck detection
is_phase_stuck() {
    local phase=$1
    local action=$2
    local last_action="${PHASE_LAST_ACTION[$phase]:-}"
    local stuck_count="${PHASE_STUCK_COUNT[$phase]:-0}"

    if [[ "$action" == "$last_action" ]]; then
        stuck_count=$((stuck_count + 1))
        PHASE_STUCK_COUNT["$phase"]=$stuck_count
        if [[ $stuck_count -ge 3 ]]; then
            return 0  # Is stuck
        fi
    else
        PHASE_STUCK_COUNT["$phase"]=1
        PHASE_LAST_ACTION["$phase"]="$action"
    fi

    return 1  # Not stuck
}

# Run GSD command in parallel mode (output to log file only)
run_gsd_command_parallel() {
    local gsd_command=$1
    local phase=$2
    local logfile=$3
    local prompt
    prompt=$(build_prompt "$gsd_command")

    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') Starting /gsd:$gsd_command for phase $phase" >> "$logfile"

    if [[ "$DRY_RUN" == true ]]; then
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [DRY RUN] Would execute: claude -p '...' --allowedTools '*'" >> "$logfile"
        echo "RALPH_STATUS: COMMAND_COMPLETE" >> "$logfile"
        return 0
    fi

    cd "$PROJECT_DIR"

    timeout $PHASE_TIMEOUT env -u CLAUDECODE claude -p "$prompt" \
        --dangerously-skip-permissions \
        --verbose \
        --output-format stream-json \
        --allowedTools '*' >> "$logfile" 2>&1
    local exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') PHASE TIMED OUT after ${PHASE_TIMEOUT}s: /gsd:$gsd_command" >> "$logfile"
        PHASE_STUCK_COUNT["$phase"]=$(( ${PHASE_STUCK_COUNT[$phase]:-0} + 1 ))
        return $exit_code
    elif [[ $exit_code -eq 0 ]]; then
        echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') Command completed: /gsd:$gsd_command" >> "$logfile"
        return 0
    else
        echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') Command failed: /gsd:$gsd_command" >> "$logfile"
        return $exit_code
    fi
}

# Merge parallel phase logs into main log and extract deferred items
merge_phase_logs() {
    if [[ ! -d "$PARALLEL_LOG_DIR" ]]; then
        return 0
    fi

    for logfile in "$PARALLEL_LOG_DIR"/*.log; do
        if [[ ! -f "$logfile" ]]; then
            continue
        fi

        local phase_num
        phase_num=$(basename "$logfile" .log | sed 's/phase-//')

        log_info "=== Output from Phase $phase_num ==="

        # Append to main log
        cat "$logfile" >> "$LOG_FILE"

        # Extract deferred items
        if grep -qi "checkpoint:human-verify\|needs.*verification\|verify.*manually" "$logfile"; then
            log_deferred "Visual verification needed" "$phase_num"
        fi

        if grep -qi "checkpoint:human-action\|manual.*action\|human.*required" "$logfile"; then
            local action_desc
            action_desc=$(grep -oP '(?<=checkpoint:human-action[:\s])[^"]*' "$logfile" 2>/dev/null | head -1 || echo "Manual action")
            log_deferred "Manual action: $action_desc" "$phase_num"
        fi

        # Check completion status
        if grep -q "RALPH_STATUS: COMMAND_COMPLETE" "$logfile"; then
            log_success "Phase $phase_num completed"
        elif grep -q "RALPH_STATUS: ERROR" "$logfile"; then
            log_error "Phase $phase_num failed"
        fi
    done
}

#=============================================================================
# Claude Invocation
#=============================================================================

# Run Claude with the GSD command
run_gsd_command() {
    local gsd_command=$1
    local prompt
    prompt=$(build_prompt "$gsd_command")

    local temp_output
    temp_output=$(mktemp)

    log_info "Running: /gsd:$gsd_command"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would execute: claude -p '...' --allowedTools '*'"
        echo "RALPH_STATUS: COMMAND_COMPLETE"
        return 0
    fi

    # Run Claude with the prompt
    # Using stream-json for real-time output parsing
    cd "$PROJECT_DIR"

    timeout $PHASE_TIMEOUT env -u CLAUDECODE claude -p "$prompt" \
        --dangerously-skip-permissions \
        --verbose \
        --output-format stream-json \
        --allowedTools '*' \
        2>&1 | tee "$temp_output" | parse_claude_output
    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 124 ]]; then
        log_warn "PHASE TIMED OUT after ${PHASE_TIMEOUT}s: /gsd:$gsd_command"
        rm -f "$temp_output"
        return $exit_code
    elif [[ $exit_code -eq 0 ]]; then
        log_success "Command completed: /gsd:$gsd_command"
        rm -f "$temp_output"
        return 0
    else
        log_error "Command failed: /gsd:$gsd_command"

        # Check for specific error patterns
        if grep -q "RALPH_STATUS: ERROR" "$temp_output"; then
            local error_msg
            error_msg=$(grep "RALPH_ERROR:" "$temp_output" | head -1 | sed 's/.*RALPH_ERROR: //')
            log_error "Error details: $error_msg"
        fi

        rm -f "$temp_output"
        return $exit_code
    fi
}

# Parse Claude's output stream
parse_claude_output() {
    local current_phase
    current_phase=$(get_current_phase)
    local found_complete=false
    local found_error=false

    while IFS= read -r line; do
        # Log raw output for debugging
        echo "$line" >> "$LOG_FILE"

        # Try to extract text content from JSON if present
        local text_content=""
        if echo "$line" | grep -q '"type":"text"'; then
            text_content=$(echo "$line" | grep -oP '"text"\s*:\s*"\K[^"]*' 2>/dev/null || true)
        fi

        # Check for checkpoint patterns
        if echo "$line" | grep -qi "checkpoint:human-verify\|needs.*verification\|verify.*manually"; then
            log_deferred "Visual verification needed" "$current_phase"
        fi

        if echo "$line" | grep -qi "checkpoint:human-action\|manual.*action\|human.*required"; then
            local action_desc
            action_desc=$(echo "$line" | grep -oP '(?<=checkpoint:human-action[:\s])[^"]*' || echo "Manual action")
            log_deferred "Manual action: $action_desc" "$current_phase"
        fi

        if echo "$line" | grep -qi "checkpoint:decision\|AUTO-DECIDED"; then
            log_info "Auto-decision made in output"
        fi

        # Check for completion signal
        if echo "$line" | grep -q "RALPH_STATUS: COMMAND_COMPLETE"; then
            found_complete=true
        fi

        # Check for error signal
        if echo "$line" | grep -q "RALPH_STATUS: ERROR"; then
            found_error=true
        fi

        # Show progress to user (extract meaningful content)
        if [[ -n "$text_content" ]]; then
            echo -e "${CYAN}>${NC} $text_content"
        fi
    done

    if [[ "$found_error" == true ]]; then
        return 1
    fi

    # Even if we didn't see explicit completion, check if the command succeeded
    # by examining the state files
    return 0
}

#=============================================================================
# Test Detection and Git Checkpoint / Rollback
#=============================================================================

detect_test_command() {
    local dir="${1:-.}"
    if [[ -f "$dir/package.json" ]]; then
        if grep -q '"test"' "$dir/package.json" 2>/dev/null; then
            local test_cmd
            test_cmd=$(python3 -c "import json; d=json.load(open('$dir/package.json')); print(d.get('scripts',{}).get('test',''))" 2>/dev/null)
            if [[ -n "$test_cmd" && "$test_cmd" != *"Error: no test specified"* ]]; then
                echo "cd '$dir' && npm test"
                return 0
            fi
        fi
    fi
    if [[ -f "$dir/bun.lockb" || -f "$dir/bunfig.toml" ]]; then
        echo "cd '$dir' && bun test"
        return 0
    fi
    if [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/pytest.ini" ]]; then
        echo "cd '$dir' && python -m pytest"
        return 0
    fi
    if [[ -f "$dir/Cargo.toml" ]]; then
        echo "cd '$dir' && cargo test"
        return 0
    fi
    if [[ -f "$dir/go.mod" ]]; then
        echo "cd '$dir' && go test ./..."
        return 0
    fi
    return 1
}

checkpoint_phase() {
    local phase="$1"
    local tag="pre-phase-${phase}-$(date +%s)"
    git -C "$PROJECT_DIR" tag "$tag" 2>/dev/null && echo "$tag"
}

rollback_phase() {
    local phase="$1"
    local tag="$2"
    if [[ -n "$tag" ]] && git -C "$PROJECT_DIR" rev-parse "$tag" >/dev/null 2>&1; then
        log_warn "Rolling back phase $phase to checkpoint $tag"
        git -C "$PROJECT_DIR" reset --hard "$tag" 2>/dev/null
        return $?
    fi
    return 1
}

run_tests() {
    local project_dir="${1:-.}"
    local test_cmd
    test_cmd=$(detect_test_command "$project_dir") || return 0  # No tests = pass
    log_info "Running tests: $test_cmd"
    if timeout 300 bash -c "$test_cmd" >/dev/null 2>&1; then
        log_info "Tests PASSED"
        return 0
    else
        log_warn "Tests FAILED"
        return 1
    fi
}

#=============================================================================
# Cost Tracking
#=============================================================================

track_command_cost() {
    local phase="$1" action="$2" log_file="$3"
    local cost_file="${PROJECT_DIR}/.planning/ralph-gsd-costs.json"
    if type cost_append &>/dev/null && [[ -f "$log_file" ]]; then
        local input_tokens output_tokens
        input_tokens=$(grep -oP '"input_tokens":\s*\K\d+' "$log_file" | tail -1)
        output_tokens=$(grep -oP '"output_tokens":\s*\K\d+' "$log_file" | tail -1)
        cost_append "$cost_file" "phase-${phase}-${action}" "${input_tokens:-0}" "${output_tokens:-0}" "sonnet"
    fi
}

#=============================================================================
# Main Loop
#=============================================================================

main_loop() {
    log_info "Starting Ralph-GSD orchestrator v$VERSION"
    log_info "Project: $PROJECT_DIR"
    log_info "Max iterations: $MAX_ITERATIONS"
    log_info "Max parallel: $MAX_PARALLEL"
    log_info "Skip discuss: $SKIP_DISCUSS"
    log_info "Dry run: $DRY_RUN"
    log_info "Resume: $RESUME"
    [[ -n "$STOP_FILE_EXTERNAL" ]] && log_info "External stop file: $STOP_FILE_EXTERNAL"

    init_deferred

    # Parse phase dependencies once at startup
    parse_all_dependencies || {
        log_error "Failed to parse dependencies"
        return 1
    }

    # Create parallel log directory
    PARALLEL_LOG_DIR="$PROJECT_DIR/.planning/ralph-gsd-parallel"
    mkdir -p "$PARALLEL_LOG_DIR"

    ITERATION=0
    local exit_reason="complete"
    local stop_detected=false

    while [[ $ITERATION -lt $MAX_ITERATIONS ]]; do
        ITERATION=$((ITERATION + 1))

        log_info "=== Iteration $ITERATION of $MAX_ITERATIONS ==="

        # Check for STOP file at the top of each iteration (before doing any work)
        if is_stop_requested; then
            log_warn "STOP requested — finishing current state and exiting gracefully"
            stop_detected=true
            exit_reason="stopped"
            break
        fi

        # Get all ready phases
        local ready_phases
        ready_phases=$(get_ready_phases)

        if [[ "$ready_phases" == "COMPLETE" ]]; then
            log_success "All phases complete!"
            exit_reason="complete"
            break
        fi

        if [[ "$ready_phases" == "DEADLOCK" ]]; then
            log_error "Deadlock detected: phases remaining but none have dependencies met"
            log_error "Manual intervention required"
            exit_reason="deadlock"
            break
        fi

        if [[ "$ready_phases" == "ERROR" ]]; then
            log_error "No phases found in ROADMAP.md"
            exit_reason="error"
            break
        fi

        # Convert to array
        local -a ready_array=($ready_phases)
        local ready_count=${#ready_array[@]}

        log_info "Ready phases: $ready_count (${ready_phases})"

        # Sequential execution for single phase
        if [[ $ready_count -eq 1 ]]; then
            local phase="${ready_array[0]}"
            local status
            status=$(get_phase_status "$phase")

            RALPH_CURRENT_PHASE="$phase"
            log_phase "Phase $phase - Status: $status"

            # --resume: skip phases that are already verified
            if [[ "$RESUME" == true ]] && [[ "$status" == "verified" ]]; then
                log_info "Resume mode: phase $phase already verified, skipping"
                continue
            fi

            # Determine next action
            local action
            action=$(determine_next_action "$phase")

            if [[ "$action" == "NEXT_PHASE" ]]; then
                log_info "Phase $phase verified, moving to next phase"
                continue
            fi

            if [[ "$action" == "ERROR" ]]; then
                log_error "Could not determine action for phase $phase"
                exit_reason="error"
                break
            fi

            # Per-phase stuck detection
            if is_phase_stuck "$phase" "$action"; then
                log_error "Phase $phase stuck: '$action' repeated 3 times without status change"
                log_deferred "Phase $phase stuck on $action" "$phase"
                PHASE_SKIPPED["$phase"]=1
                continue  # Skip this phase, continue with others
            fi

            log_info "Action: /gsd:$action"

            # Checkpoint before execute-phase so we can roll back on test failure
            local checkpoint_tag=""
            if [[ "$action" == *"execute-phase"* ]]; then
                checkpoint_tag=$(checkpoint_phase "$phase") || true
            fi

            # Run the GSD command with terminal output
            local cmd_exit=0
            run_gsd_command "$action" || cmd_exit=$?

            # Track cost using last temp log approximation via LOG_FILE
            track_command_cost "$phase" "$action" "$LOG_FILE"

            if [[ $cmd_exit -eq 124 ]]; then
                log_warn "Phase $phase timed out — incrementing stuck counter"
                PHASE_STUCK_COUNT["$phase"]=$(( ${PHASE_STUCK_COUNT[$phase]:-0} + 1 ))
            elif [[ $cmd_exit -ne 0 ]]; then
                log_error "Command failed for phase $phase"
                # Don't break - continue with other phases
            fi

            # Post-execute test gate with rollback
            if [[ "$action" == *"execute-phase"* ]]; then
                if ! run_tests "$PROJECT_DIR"; then
                    if [[ -n "$checkpoint_tag" ]]; then
                        rollback_phase "$phase" "$checkpoint_tag"
                        PHASE_STUCK_COUNT["$phase"]=$(( ${PHASE_STUCK_COUNT[$phase]:-0} + 1 ))
                        log_warn "Phase $phase rolled back due to test failure. Will re-plan."
                        continue
                    fi
                fi
            fi

        # Parallel execution for multiple phases
        else
            # Cap at MAX_PARALLEL
            local phases_to_run=("${ready_array[@]:0:$MAX_PARALLEL}")
            local -a pids=()
            local -a phase_actions=()

            log_info "Executing ${#phases_to_run[@]} phases in parallel"

            # Clean up old logs
            rm -f "$PARALLEL_LOG_DIR"/*.log

            # Dispatch parallel jobs
            for phase in "${phases_to_run[@]}"; do
                RALPH_CURRENT_PHASE="$phase"

                # --resume: skip phases that are already verified
                if [[ "$RESUME" == true ]]; then
                    local pstatus
                    pstatus=$(get_phase_status "$phase")
                    if [[ "$pstatus" == "verified" ]]; then
                        log_info "Resume mode: phase $phase already verified, skipping"
                        continue
                    fi
                fi

                local action
                action=$(determine_next_action "$phase")

                if [[ "$action" == "NEXT_PHASE" ]] || [[ "$action" == "ERROR" ]]; then
                    continue
                fi

                # Per-phase stuck detection
                if is_phase_stuck "$phase" "$action"; then
                    log_warn "Phase $phase stuck: '$action' repeated 3 times - skipping"
                    log_deferred "Phase $phase stuck on $action" "$phase"
                    PHASE_SKIPPED["$phase"]=1
                    continue
                fi

                local logfile="$PARALLEL_LOG_DIR/phase-$phase.log"
                log_info "Starting phase $phase in background: /gsd:$action"

                # Run in background
                run_gsd_command_parallel "$action" "$phase" "$logfile" &
                pids+=($!)
                phase_actions+=("$phase:$action")
            done

            # Wait for all parallel jobs
            if [[ ${#pids[@]} -gt 0 ]]; then
                log_info "Waiting for ${#pids[@]} parallel jobs to complete"
                for pid in "${pids[@]}"; do
                    wait "$pid" || log_warn "Job $pid exited with error"
                done
                log_success "All parallel jobs completed"

                # Merge logs and extract deferred items
                merge_phase_logs

                # Track cost for each parallel phase log
                for pa in "${phase_actions[@]}"; do
                    local pa_phase="${pa%%:*}"
                    local pa_action="${pa#*:}"
                    local pa_logfile="$PARALLEL_LOG_DIR/phase-${pa_phase}.log"
                    track_command_cost "$pa_phase" "$pa_action" "$pa_logfile"
                done

                # Clean up log directory
                rm -rf "$PARALLEL_LOG_DIR"/*.log
            else
                log_warn "No phases dispatched in this iteration"
            fi
        fi

        # Small delay between iterations
        sleep 1
    done

    # Handle iteration limit exhaustion (not a stop file, just ran out)
    if [[ $ITERATION -ge $MAX_ITERATIONS ]] && [[ "$exit_reason" == "complete" ]] && ! is_milestone_complete; then
        exit_reason="error"
    fi

    # Count phases for machine-readable output
    local all_phases phases_complete phases_total
    all_phases=$(get_phases 2>/dev/null || true)
    phases_total=$(echo "$all_phases" | wc -w | tr -d ' ')
    phases_complete=0
    for p in $all_phases; do
        [[ "$(get_phase_status "$p")" == "verified" ]] && phases_complete=$((phases_complete + 1))
    done

    # Final summary
    echo ""
    log_info "=== Ralph-GSD Summary ==="
    log_info "Iterations completed: $ITERATION"

    if is_milestone_complete; then
        log_success "Milestone fully completed!"
        exit_reason="complete"
    else
        local current_phase
        current_phase=$(get_current_phase)
        RALPH_CURRENT_PHASE="${current_phase:-none}"
        if [[ "$current_phase" != "COMPLETE" ]] && [[ "$current_phase" != "ERROR" ]]; then
            local status
            status=$(get_phase_status "$current_phase")
            log_warn "Stopped at phase $current_phase (status: $status)"
        fi
    fi

    # Show deferred items
    local deferred_file="$PROJECT_DIR/.planning/DEFERRED.md"
    if [[ -f "$deferred_file" ]]; then
        local deferred_count
        deferred_count=$(grep -c '^\- \[ \]' "$deferred_file" 2>/dev/null) || deferred_count=0
        if [[ "$deferred_count" -gt 0 ]]; then
            log_warn "Deferred items requiring review: $deferred_count"
            log_info "Review with: cat $deferred_file"
        fi
    fi

    log_info "Log file: $LOG_FILE"

    # Clean up parallel log directory
    rm -rf "$PARALLEL_LOG_DIR"

    # Determine final exit code
    local final_code
    case "$exit_reason" in
        complete)  final_code=$EXIT_COMPLETE ;;
        stopped)   final_code=$EXIT_STOPPED ;;
        deadlock)  final_code=$EXIT_DEADLOCK ;;
        *)         final_code=$EXIT_ERROR ;;
    esac

    # Remove STOP files on graceful stop so a --resume run can proceed
    if [[ "$exit_reason" == "stopped" ]]; then
        cleanup_stop_files
    fi

    # Post-milestone evaluator gate
    if [[ "$exit_reason" == "complete" ]] && [[ "$SKIP_EVALUATOR" != "true" ]]; then
        log_info "=== Running post-milestone evaluator ==="
        local eval_prompt="You are an independent code evaluator. Review ALL changes in the current git log (last 50 commits or since the last milestone tag).

Check for:
1. Security vulnerabilities (OWASP Top 10, hardcoded secrets, injection risks)
2. Test coverage gaps (new features without tests)
3. Code quality issues (dead code, duplicated logic, overly complex functions)
4. Unused dependencies
5. Performance concerns (N+1 queries, missing indexes, large bundle sizes)

For each finding, output:
- SEVERITY: CRITICAL | HIGH | MEDIUM | LOW
- FILE: path
- ISSUE: description
- SUGGESTION: fix

At the end, output either:
EVALUATOR_STATUS: PASSED (no critical/high issues)
EVALUATOR_STATUS: ISSUES_FOUND (has critical/high issues)

Always output the full list of findings regardless of status."

        local eval_log="$PROJECT_DIR/.planning/evaluator-$(date +%s).log"
        timeout $PHASE_TIMEOUT env -u CLAUDECODE claude -p "$eval_prompt" \
            --dangerously-skip-permissions --verbose --allowedTools '*' \
            2>&1 | tee "$eval_log"

        if grep -q "EVALUATOR_STATUS: ISSUES_FOUND" "$eval_log"; then
            log_warn "Evaluator found issues — see $eval_log"
            echo -e "\n## Evaluator Findings ($(date))\n" >> "${PROJECT_DIR}/.planning/DEFERRED.md"
            grep -A2 "SEVERITY:" "$eval_log" >> "${PROJECT_DIR}/.planning/DEFERRED.md" 2>/dev/null
        else
            log_info "Evaluator: PASSED"
        fi
    fi

    # Print cost summary if tracker is available
    if type cost_total &>/dev/null; then
        local cost_file="${PROJECT_DIR}/.planning/ralph-gsd-costs.json"
        if [[ -f "$cost_file" ]]; then
            log_info "=== Cost Summary ==="
            cost_total "$cost_file"
        fi
    fi

    ralph_exit "$final_code" "$phases_complete" "$phases_total" "${RALPH_CURRENT_PHASE:-none}"
}

#=============================================================================
# Entry Point
#=============================================================================

main() {
    parse_args "$@"
    main_loop
}

main "$@"
