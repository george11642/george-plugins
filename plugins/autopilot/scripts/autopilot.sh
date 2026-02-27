#!/usr/bin/env bash
#
# autopilot.sh — Autonomous overnight coding loop
#
# Spawns fresh Claude Code instances in a loop. Each instance:
#   1. Reads mission + progress + handoff from .autopilot/
#   2. Picks the next task
#   3. Researches, implements, tests, commits
#   4. Updates progress + handoff for the next instance
#
# Usage:
#   autopilot.sh --project-dir PATH [options]
#
# Author: George Teifel
# License: MIT

set -euo pipefail

#=============================================================================
# Configuration
#=============================================================================

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR=""
MAX_ITERATIONS=50
MAX_HOURS=8
MAX_PARALLEL=3
SKIP_DISCUSS=false
RESUME=false
DRY_RUN=false
ITERATION=0
START_TIME=""
AUTOPILOT_DIR=""
LOG_FILE=""

# GSD execute mode state
declare -A GSD_PHASE_DEPS
declare -A GSD_PHASE_STUCK_COUNT
declare -A GSD_PHASE_LAST_ACTION
declare -A GSD_PHASE_SKIPPED

#=============================================================================
# Colors
#=============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[autopilot]${NC} $*"; echo "[INFO] $(date '+%H:%M:%S') $*" >> "$LOG_FILE" 2>/dev/null || true; }
log_success() { echo -e "${GREEN}[autopilot]${NC} $*"; echo "[OK]   $(date '+%H:%M:%S') $*" >> "$LOG_FILE" 2>/dev/null || true; }
log_warn()    { echo -e "${YELLOW}[autopilot]${NC} $*"; echo "[WARN] $(date '+%H:%M:%S') $*" >> "$LOG_FILE" 2>/dev/null || true; }
log_error()   { echo -e "${RED}[autopilot]${NC} $*" >&2; echo "[ERR]  $(date '+%H:%M:%S') $*" >> "$LOG_FILE" 2>/dev/null || true; }
log_phase()   { echo -e "${MAGENTA}[autopilot]${NC} ═══ $* ═══"; echo "[PHASE] $(date '+%H:%M:%S') $*" >> "$LOG_FILE" 2>/dev/null || true; }

#=============================================================================
# Argument Parsing
#=============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-dir)   PROJECT_DIR="$2"; shift 2 ;;
            --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
            --hours)         MAX_HOURS="$2"; shift 2 ;;
            --parallel)      MAX_PARALLEL="$2"; shift 2 ;;
            --skip-discuss)  SKIP_DISCUSS=true; shift ;;
            --resume)        RESUME=true; shift ;;
            --dry-run)       DRY_RUN=true; shift ;;
            --help)          show_help; exit 0 ;;
            *)               log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    [[ -z "$PROJECT_DIR" ]] && { log_error "--project-dir required"; exit 1; }
    PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || { log_error "Dir not found: $PROJECT_DIR"; exit 1; }

    AUTOPILOT_DIR="$PROJECT_DIR/.autopilot"
    LOG_FILE="$AUTOPILOT_DIR/loop.log"

    [[ ! -d "$AUTOPILOT_DIR" ]] && { log_error "No .autopilot/ directory. Run /autopilot first."; exit 1; }
    [[ ! -f "$AUTOPILOT_DIR/mission.json" ]] && { log_error "No mission.json found."; exit 1; }
}

show_help() {
    cat << 'EOF'
autopilot.sh — Autonomous overnight coding loop

USAGE:
    autopilot.sh --project-dir PATH [options]

OPTIONS:
    --project-dir PATH     Project root (must contain .autopilot/)
    --max-iterations N     Max iterations before stopping (default: 50)
    --hours N              Max runtime in hours (default: 8)
    --parallel N           Max parallel subagents per iteration (default: 3)
    --resume               Resume from existing progress state
    --dry-run              Show what would happen without executing
    --help                 Show this help
EOF
}

#=============================================================================
# State Management
#=============================================================================

# Read a JSON field from a file using grep/sed (no jq dependency)
json_field() {
    local file="$1" field="$2"
    grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"$//'
}

json_field_num() {
    local file="$1" field="$2"
    grep -o "\"$field\"[[:space:]]*:[[:space:]]*[0-9]*" "$file" 2>/dev/null | head -1 | sed 's/.*: *//'
}

get_mission() { json_field "$AUTOPILOT_DIR/mission.json" "mission"; }
get_mode()    { json_field "$AUTOPILOT_DIR/mission.json" "mode"; }
get_status()  { json_field "$AUTOPILOT_DIR/mission.json" "status"; }

get_iteration() { json_field_num "$AUTOPILOT_DIR/progress.json" "iteration"; }

get_pending_count() {
    grep -c '"status"[[:space:]]*:[[:space:]]*"pending"' "$AUTOPILOT_DIR/progress.json" 2>/dev/null || echo "0"
}

get_completed_count() {
    grep -c '"status"[[:space:]]*:[[:space:]]*"completed"' "$AUTOPILOT_DIR/progress.json" 2>/dev/null || echo "0"
}

get_total_tasks() {
    local pending completed skipped errored
    pending=$(get_pending_count)
    completed=$(get_completed_count)
    skipped=$(grep -c '"status"[[:space:]]*:[[:space:]]*"skipped"' "$AUTOPILOT_DIR/progress.json" 2>/dev/null || echo "0")
    errored=$(grep -c '"status"[[:space:]]*:[[:space:]]*"error"' "$AUTOPILOT_DIR/progress.json" 2>/dev/null || echo "0")
    echo $((pending + completed + skipped + errored))
}

# Check if we should stop
should_stop() {
    # Stop signal file
    [[ -f "$AUTOPILOT_DIR/STOP" ]] && { log_info "Stop signal detected"; return 0; }

    # Mission status
    local status
    status=$(get_status)
    [[ "$status" == "complete" || "$status" == "stopped" ]] && return 0

    # Max iterations
    [[ $ITERATION -ge $MAX_ITERATIONS ]] && { log_warn "Max iterations reached ($MAX_ITERATIONS)"; return 0; }

    # Time limit
    local elapsed_hours
    elapsed_hours=$(( ($(date +%s) - START_TIME) / 3600 ))
    [[ $elapsed_hours -ge $MAX_HOURS ]] && { log_warn "Time limit reached (${MAX_HOURS}h)"; return 0; }

    # No pending tasks
    local pending
    pending=$(get_pending_count)
    [[ "$pending" -eq 0 ]] && { log_success "All tasks complete!"; return 0; }

    return 1
}

#=============================================================================
# GSD Execute Mode — State Detection & Command Mapping
#=============================================================================

# Get list of phases from ROADMAP.md
gsd_get_phases() {
    local roadmap="$PROJECT_DIR/.planning/ROADMAP.md"
    [[ ! -f "$roadmap" ]] && { log_error "ROADMAP.md not found"; return 1; }
    grep -oE 'Phase [0-9]+' "$roadmap" | grep -oE '[0-9]+' | sort -u -n
}

# Get status of a GSD phase
gsd_get_phase_status() {
    local phase=$1
    local state_file="$PROJECT_DIR/.planning/STATE.md"
    local phase_dir="$PROJECT_DIR/.planning/phases"

    # Check STATE.md for completion
    if [[ -f "$state_file" ]]; then
        if grep -E "^\|[[:space:]]*$phase\.[[:space:]].*\|[[:space:]]*Completed[[:space:]]*\|" "$state_file" >/dev/null 2>&1; then
            echo "verified"; return
        fi
    fi

    local phase_padded=$(printf "%02d" "$phase")
    local phase_path=""

    # Find phase directory (handles 06, 06-name, etc.)
    if [[ -d "$phase_dir/$phase_padded" ]]; then
        phase_path="$phase_dir/$phase_padded"
    elif [[ -d "$phase_dir/$phase" ]]; then
        phase_path="$phase_dir/$phase"
    else
        local found_dir
        found_dir=$(find "$phase_dir" -maxdepth 1 -type d -name "${phase_padded}-*" 2>/dev/null | head -1)
        if [[ -z "$found_dir" ]]; then
            found_dir=$(find "$phase_dir" -maxdepth 1 -type d -name "${phase}-*" 2>/dev/null | head -1)
        fi
        if [[ -n "$found_dir" && -d "$found_dir" ]]; then
            phase_path="$found_dir"
        else
            echo "not_started"; return
        fi
    fi

    # Check VERIFICATION.md
    local verification_file=""
    if [[ -f "$phase_path/VERIFICATION.md" ]]; then
        verification_file="$phase_path/VERIFICATION.md"
    else
        verification_file=$(find "$phase_path" -maxdepth 1 -name "*VERIFICATION.md" 2>/dev/null | head -1)
    fi

    if [[ -n "$verification_file" && -f "$verification_file" ]]; then
        if grep -qi "VERIFIED\|PASSED\|SUCCESS\|ALL.*COMPLETE" "$verification_file" 2>/dev/null; then
            echo "verified"; return
        else
            echo "gaps"; return
        fi
    fi

    # Check PLAN and SUMMARY files
    local plan_count summary_count
    plan_count=$(find "$phase_path" -maxdepth 1 -name "*PLAN.md" 2>/dev/null | wc -l)
    summary_count=$(find "$phase_path" -maxdepth 1 -name "*SUMMARY.md" 2>/dev/null | wc -l)

    if [[ $plan_count -gt 0 && $summary_count -ge $plan_count ]]; then
        echo "executed"; return
    fi
    if [[ $plan_count -gt 0 && $summary_count -gt 0 ]]; then
        echo "partially_executed"; return
    fi
    if [[ $plan_count -gt 0 ]]; then
        echo "planned"; return
    fi

    # Check for context/research files
    if [[ -f "$phase_path/CONTEXT.md" ]] || [[ -f "$phase_path/DISCUSSION.md" ]]; then
        echo "context_captured"; return
    fi
    if compgen -G "$phase_path/*RESEARCH.md" > /dev/null 2>&1; then
        echo "context_captured"; return
    fi

    echo "not_started"
}

# Map phase status to GSD command
gsd_determine_action() {
    local phase=$1
    local status
    status=$(gsd_get_phase_status "$phase")

    case $status in
        not_started)
            if [[ "$SKIP_DISCUSS" == true ]]; then
                echo "plan-phase $phase"
            else
                echo "discuss-phase $phase"
            fi ;;
        context_captured)  echo "plan-phase $phase" ;;
        planned)           echo "execute-phase $phase" ;;
        partially_executed) echo "execute-phase $phase" ;;
        executed)          echo "verify-work $phase" ;;
        gaps)              echo "plan-phase $phase --gaps" ;;
        verified)          echo "NEXT_PHASE" ;;
        *)                 echo "ERROR" ;;
    esac
}

# Parse phase dependencies from ROADMAP.md
gsd_parse_dependencies() {
    local roadmap="$PROJECT_DIR/.planning/ROADMAP.md"
    [[ ! -f "$roadmap" ]] && return 1

    local current_phase=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^##+[[:space:]]*Phase[[:space:]]+([0-9]+) ]]; then
            current_phase="${BASH_REMATCH[1]}"
            GSD_PHASE_DEPS["$current_phase"]=""
        fi
        if [[ -n "$current_phase" ]] && [[ "$line" =~ \*\*Depends[[:space:]]+on\*\*:[[:space:]]*(.*) ]]; then
            local deps_line="${BASH_REMATCH[1]}"
            local deps=""
            while [[ "$deps_line" =~ Phase[[:space:]]+([0-9]+) ]]; do
                deps="$deps ${BASH_REMATCH[1]}"
                deps_line="${deps_line#*Phase ${BASH_REMATCH[1]}}"
            done
            GSD_PHASE_DEPS["$current_phase"]="${deps# }"
        fi
    done < "$roadmap"
}

# Check if phase dependencies are met
gsd_deps_met() {
    local phase=$1
    local deps="${GSD_PHASE_DEPS[$phase]:-}"
    [[ -z "$deps" ]] && return 0
    for dep in $deps; do
        [[ "$(gsd_get_phase_status "$dep")" != "verified" ]] && return 1
    done
    return 0
}

# Get ready phases (deps met, not verified, not stuck)
gsd_get_ready_phases() {
    local phases
    phases=$(gsd_get_phases) || { echo "ERROR"; return; }

    local ready="" all_verified=true

    for phase in $phases; do
        local status
        status=$(gsd_get_phase_status "$phase")
        [[ "$status" == "verified" ]] && continue
        all_verified=false
        [[ -n "${GSD_PHASE_SKIPPED[$phase]:-}" ]] && continue
        gsd_deps_met "$phase" && ready="$ready $phase"
    done

    if [[ "$all_verified" == true ]]; then echo "COMPLETE"; return; fi
    ready="${ready# }"
    if [[ -z "$ready" ]]; then echo "DEADLOCK"; return; fi
    echo "$ready"
}

# Per-phase stuck detection
gsd_is_stuck() {
    local phase=$1 action=$2
    local last="${GSD_PHASE_LAST_ACTION[$phase]:-}"
    local count="${GSD_PHASE_STUCK_COUNT[$phase]:-0}"

    if [[ "$action" == "$last" ]]; then
        count=$((count + 1))
        GSD_PHASE_STUCK_COUNT["$phase"]=$count
        [[ $count -ge 3 ]] && return 0
    else
        GSD_PHASE_STUCK_COUNT["$phase"]=1
        GSD_PHASE_LAST_ACTION["$phase"]="$action"
    fi
    return 1
}

# Build GSD autonomous prompt
build_gsd_prompt() {
    local gsd_command=$1

    cat << 'GSD_PREAMBLE'
## AUTOPILOT — GSD Execute Mode

You are running in autonomous mode inside the Autopilot loop, executing GSD phases.

### Checkpoint Handling
- **checkpoint:human-verify** → Log to .autopilot/handoff.md, CONTINUE. Assume correct.
- **checkpoint:decision** → Choose the most sensible option. Log: "AUTO-DECIDED: [choice] because [reason]"
- **checkpoint:human-action** → Log and SKIP. Continue with next task.

### Completion Signal
When the GSD command completes: AUTOPILOT_STATUS: ITERATION_COMPLETE
On unrecoverable error: AUTOPILOT_STATUS: ERROR
GSD_PREAMBLE

    cat << EOF

---

## Current Task

Run the following GSD command:

/gsd:$gsd_command

Work autonomously. Do not ask for human input. Make sensible default choices.
Log any skipped checkpoints to .autopilot/handoff.md.

After the GSD command completes, also update .autopilot/handoff.md with:
- What phase and step you just completed
- What the next iteration should know
- Any issues encountered

When complete, output: AUTOPILOT_STATUS: ITERATION_COMPLETE
EOF
}

# Check if GSD milestone is complete
gsd_is_complete() {
    local phases
    phases=$(gsd_get_phases) || return 1
    for phase in $phases; do
        [[ "$(gsd_get_phase_status "$phase")" != "verified" ]] && return 1
    done
    return 0
}

# GSD should_stop (overrides default for execute mode)
gsd_should_stop() {
    [[ -f "$AUTOPILOT_DIR/STOP" ]] && { log_info "Stop signal detected"; return 0; }
    local status; status=$(get_status)
    [[ "$status" == "complete" || "$status" == "stopped" ]] && return 0
    [[ $ITERATION -ge $MAX_ITERATIONS ]] && { log_warn "Max iterations ($MAX_ITERATIONS)"; return 0; }
    local elapsed=$(( ($(date +%s) - START_TIME) / 3600 ))
    [[ $elapsed -ge $MAX_HOURS ]] && { log_warn "Time limit (${MAX_HOURS}h)"; return 0; }
    gsd_is_complete && { log_success "All GSD phases complete!"; return 0; }
    return 1
}

# Run a single GSD iteration
run_gsd_iteration() {
    local gsd_command=$1
    local phase=$2

    local prompt
    prompt=$(build_gsd_prompt "$gsd_command")

    log_phase "GSD Iteration $ITERATION — /gsd:$gsd_command (Phase $phase)"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: /gsd:$gsd_command"
        return 0
    fi

    local iteration_log="$AUTOPILOT_DIR/iterations/iteration-${ITERATION}.log"
    mkdir -p "$AUTOPILOT_DIR/iterations"

    cd "$PROJECT_DIR"

    local exit_code=0
    claude -p "$prompt" \
        --dangerously-skip-permissions \
        --verbose \
        --allowedTools '*' \
        2>&1 | tee "$iteration_log" || exit_code=$?

    # Check for status signals
    if grep -q "AUTOPILOT_STATUS: BLOCKED" "$iteration_log" 2>/dev/null; then
        log_warn "Agent blocked — check .autopilot/handoff.md"
        sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "blocked"/' "$AUTOPILOT_DIR/mission.json"
        return 1
    fi

    if grep -q "AUTOPILOT_STATUS: ERROR" "$iteration_log" 2>/dev/null; then
        log_error "Error in GSD iteration $ITERATION"
    fi

    return 0
}

#=============================================================================
# GSD Execute Mode Main Loop
#=============================================================================

gsd_main_loop() {
    log_info "GSD Execute Mode — parsing .planning/ state"

    # Verify .planning/ exists
    if [[ ! -d "$PROJECT_DIR/.planning" ]]; then
        log_error "No .planning/ directory. Run /gsd:new-project first."
        return 1
    fi

    # Parse dependencies
    gsd_parse_dependencies || { log_error "Failed to parse dependencies"; return 1; }

    while ! gsd_should_stop; do
        ITERATION=$((ITERATION + 1))
        local iter_start=$(date +%s)

        # Get ready phases
        local ready
        ready=$(gsd_get_ready_phases)

        case "$ready" in
            COMPLETE)
                log_success "All GSD phases complete!"
                sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "complete"/' "$AUTOPILOT_DIR/mission.json"
                break ;;
            DEADLOCK)
                log_error "Deadlock: phases remain but none have deps met"
                break ;;
            ERROR)
                log_error "No phases found in ROADMAP.md"
                break ;;
        esac

        # Pick first ready phase and determine action
        local -a ready_array=($ready)
        local phase="${ready_array[0]}"
        local action
        action=$(gsd_determine_action "$phase")

        if [[ "$action" == "NEXT_PHASE" || "$action" == "ERROR" ]]; then
            continue
        fi

        # Stuck detection
        if gsd_is_stuck "$phase" "$action"; then
            log_warn "Phase $phase stuck on '$action' (3x) — skipping"
            GSD_PHASE_SKIPPED["$phase"]=1
            continue
        fi

        # Run the GSD command
        if ! run_gsd_iteration "$action" "$phase"; then
            break
        fi

        local duration=$(( $(date +%s) - iter_start ))
        log_info "Iteration $ITERATION took ${duration}s"

        sleep 3
    done
}

#=============================================================================
# Prompt Construction (mission/improve/research modes)
#=============================================================================

build_iteration_prompt() {
    local mission mode iteration pending completed total handoff_content
    mission=$(get_mission)
    mode=$(get_mode)
    iteration=$ITERATION
    pending=$(get_pending_count)
    completed=$(get_completed_count)
    total=$(get_total_tasks)

    # Read handoff notes
    handoff_content=""
    [[ -f "$AUTOPILOT_DIR/handoff.md" ]] && handoff_content=$(cat "$AUTOPILOT_DIR/handoff.md")

    # Read recent git log
    local recent_commits
    recent_commits=$(cd "$PROJECT_DIR" && git log --oneline -10 2>/dev/null || echo "No git history")

    # Read progress JSON for task list
    local progress_content
    progress_content=$(cat "$AUTOPILOT_DIR/progress.json")

    cat << PROMPT
## AUTOPILOT — Autonomous Coding Agent (Iteration $iteration)

You are running as an autonomous coding agent inside the Autopilot loop.
Each iteration you get a fresh context window. Your state lives in files, not memory.

### YOUR MISSION
$mission

### MODE: $mode

### PROGRESS: $completed / $total tasks complete ($pending pending)

### RECENT COMMITS
$recent_commits

### HANDOFF FROM PREVIOUS ITERATION
$handoff_content

### TASK LIST (from .autopilot/progress.json)
$progress_content

---

## YOUR PROTOCOL FOR THIS ITERATION

### Step 1: Orient (30 seconds)
- Read the task list above and identify the NEXT PENDING task (lowest index with status "pending")
- Read any relevant source files for that task
- If no pending tasks remain, output AUTOPILOT_STATUS: MISSION_COMPLETE and stop

### Step 2: Research (if needed)
- If the task requires understanding unfamiliar code, read the relevant files
- If the task requires external knowledge, use WebSearch/WebFetch
- Keep research focused — you have ONE task to complete this iteration

### Step 3: Implement
- Make the code changes needed for this ONE task
- Follow existing code patterns and conventions
- Check CLAUDE.md for project-specific rules
- Run the project's linter if available

### Step 4: Verify
- Run relevant tests (unit tests, type checking, linting)
- If tests fail, fix the issue (max 2 retries, then mark task as error)
- For UI changes, take a screenshot if browser tools are available

### Step 5: Commit
- Stage ONLY the files you changed
- Write a concise commit message describing what you did
- Push to the current branch

### Step 6: Update State
- Update .autopilot/progress.json:
  - Set current task status to "completed" (or "error" with notes)
  - Increment the "iteration" counter
  - Add commit hash to "commits" array
  - Add any learnings to "learnings" array
- Update .autopilot/handoff.md with:
  - What you just did
  - What the next task should know
  - Any issues or blockers discovered
  - Key files you touched

### Step 7: Signal Completion
Output exactly: AUTOPILOT_STATUS: ITERATION_COMPLETE

---

## RULES

1. ONE TASK PER ITERATION. Do not try to do multiple tasks. Quality > quantity.
2. ALWAYS commit your work before finishing. Uncommitted work is lost work.
3. ALWAYS update progress.json and handoff.md. The next iteration depends on it.
4. If a task is unclear, make your best judgment and document the decision.
5. If a task fails after 2 retries, mark it as "error" with notes and move on.
6. NEVER modify .autopilot/mission.json — that's the user's intent.
7. NEVER delete files without strong justification. Prefer editing.
8. NEVER run destructive database operations.
9. Keep commits atomic — one logical change per commit.
10. If you discover new work that should be done, add it as a new task in progress.json.

## ERROR SIGNALS
- AUTOPILOT_STATUS: ITERATION_COMPLETE (normal — task done)
- AUTOPILOT_STATUS: MISSION_COMPLETE (all tasks done)
- AUTOPILOT_STATUS: ERROR (unrecoverable — describe in handoff.md)
- AUTOPILOT_STATUS: BLOCKED (needs human — describe in handoff.md)
PROMPT
}

#=============================================================================
# Claude Invocation
#=============================================================================

run_iteration() {
    local prompt
    prompt=$(build_iteration_prompt)

    log_phase "Iteration $ITERATION — $(get_pending_count) tasks remaining"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run claude -p '...' --dangerously-skip-permissions"
        return 0
    fi

    local iteration_log="$AUTOPILOT_DIR/iterations/iteration-${ITERATION}.log"
    mkdir -p "$AUTOPILOT_DIR/iterations"

    cd "$PROJECT_DIR"

    # Run Claude with fresh context
    local exit_code=0
    claude -p "$prompt" \
        --dangerously-skip-permissions \
        --verbose \
        --allowedTools '*' \
        2>&1 | tee "$iteration_log" || exit_code=$?

    # Parse output for status signals
    if grep -q "AUTOPILOT_STATUS: MISSION_COMPLETE" "$iteration_log" 2>/dev/null; then
        log_success "Mission complete!"
        # Update mission status
        sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "complete"/' "$AUTOPILOT_DIR/mission.json"
        return 1  # Signal to stop loop
    fi

    if grep -q "AUTOPILOT_STATUS: BLOCKED" "$iteration_log" 2>/dev/null; then
        log_warn "Agent is blocked — needs human intervention"
        log_warn "Check .autopilot/handoff.md for details"
        sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "blocked"/' "$AUTOPILOT_DIR/mission.json"
        return 1  # Signal to stop loop
    fi

    if grep -q "AUTOPILOT_STATUS: ERROR" "$iteration_log" 2>/dev/null; then
        log_error "Unrecoverable error in iteration $ITERATION"
        # Don't stop — let the next iteration try the next task
    fi

    return 0
}

#=============================================================================
# Main Loop
#=============================================================================

main() {
    parse_args "$@"

    START_TIME=$(date +%s)

    # Write PID file for status/stop commands
    echo $$ > "$AUTOPILOT_DIR/loop.pid"

    # Trap cleanup
    trap 'rm -f "$AUTOPILOT_DIR/loop.pid"; log_info "Loop terminated"' EXIT

    log_info "╔══════════════════════════════════════════╗"
    log_info "║       AUTOPILOT v$VERSION — Starting       ║"
    log_info "╚══════════════════════════════════════════╝"
    log_info "Mission: $(get_mission)"
    log_info "Mode: $(get_mode)"
    log_info "Max iterations: $MAX_ITERATIONS"
    log_info "Time limit: ${MAX_HOURS}h"
    log_info "Project: $PROJECT_DIR"

    # Resume from previous state
    if [[ "$RESUME" == true ]]; then
        ITERATION=$(get_iteration)
        log_info "Resuming from iteration $ITERATION"
    fi

    # Route to the correct loop based on mode
    local mode
    mode=$(get_mode)

    if [[ "$mode" == "execute" ]]; then
        # GSD Execute Mode — uses actual GSD agents and commands
        gsd_main_loop
    else
        # Mission/Improve/Research — autopilot's own task loop
        while ! should_stop; do
            ITERATION=$((ITERATION + 1))

            local iteration_start
            iteration_start=$(date +%s)

            if ! run_iteration; then
                break  # Mission complete or blocked
            fi

            local iteration_duration=$(( $(date +%s) - iteration_start ))
            log_info "Iteration $ITERATION took ${iteration_duration}s"

            # Brief pause between iterations (let file system sync, rate limits)
            sleep 3
        done
    fi

    # Final summary
    local total_time=$(( ($(date +%s) - START_TIME) / 60 ))
    local completed
    completed=$(get_completed_count)
    local total
    total=$(get_total_tasks)

    echo ""
    log_info "╔══════════════════════════════════════════╗"
    log_info "║       AUTOPILOT — Session Complete       ║"
    log_info "╚══════════════════════════════════════════╝"
    log_info "Iterations: $ITERATION"
    log_info "Runtime: ${total_time} minutes"
    log_info "Tasks completed: $completed / $total"
    log_info "Status: $(get_status)"
    log_info "Log: $LOG_FILE"

    # Clean up
    rm -f "$AUTOPILOT_DIR/STOP"
    rm -f "$AUTOPILOT_DIR/loop.pid"
}

main "$@"
