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
#   --dry-run             Show what would happen without executing
#   --help                Show this help message
#
# Author: George (via Claude)
# License: MIT

set -euo pipefail

#=============================================================================
# Configuration
#=============================================================================

VERSION="1.1.0"
DEFAULT_MAX_ITERATIONS=100
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE=""
PROJECT_DIR=""
MAX_ITERATIONS=$DEFAULT_MAX_ITERATIONS
SKIP_DISCUSS=false
DRY_RUN=false
ITERATION=0

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
    --dry-run             Show planned actions without executing
    --help                Show this help message
    --version             Show version information

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

WORKFLOW:
    1. Create milestone: claude > /gsd:new-project "My Feature"
    2. Start Ralph: ralph-gsd.sh --project-dir .
    3. Ralph executes: discuss → plan → execute → verify (per phase)
    4. Review deferred: cat .planning/DEFERRED.md

FILES:
    .planning/STATE.md      Current milestone state
    .planning/ROADMAP.md    Phase definitions
    .planning/DEFERRED.md   Skipped checkpoints for review

EXAMPLES:
    # Execute milestone with default settings
    ralph-gsd.sh --project-dir ~/projects/myapp

    # Limit iterations and skip discuss phases
    ralph-gsd.sh --project-dir . --max-iterations 50 --skip-discuss

    # Preview what would happen
    ralph-gsd.sh --project-dir . --dry-run

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
            --dry-run)
                DRY_RUN=true
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

    # Set up log file
    LOG_FILE="$PROJECT_DIR/.planning/ralph-gsd.log"
}

#=============================================================================
# State Detection
#=============================================================================

# Get list of phases from ROADMAP.md
get_phases() {
    local roadmap="$PROJECT_DIR/.planning/ROADMAP.md"

    if [[ ! -f "$roadmap" ]]; then
        log_error "ROADMAP.md not found"
        return 1
    fi

    # Extract phase numbers from ROADMAP.md
    # Looking for patterns like "## Phase 01:" or "### Phase 1:"
    grep -oE 'Phase [0-9]+' "$roadmap" | grep -oE '[0-9]+' | sort -u -n
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
# Deferred Human Involvement Items

Items logged by Ralph-GSD that need human review after milestone completion.

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

    if claude -p "$prompt" \
        --dangerously-skip-permissions \
        --verbose \
        --output-format stream-json \
        --allowedTools '*' \
        2>&1 | tee "$temp_output" | parse_claude_output; then
        log_success "Command completed: /gsd:$gsd_command"
        rm -f "$temp_output"
        return 0
    else
        local exit_code=$?
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
# Main Loop
#=============================================================================

main_loop() {
    log_info "Starting Ralph-GSD orchestrator"
    log_info "Project: $PROJECT_DIR"
    log_info "Max iterations: $MAX_ITERATIONS"
    log_info "Skip discuss: $SKIP_DISCUSS"
    log_info "Dry run: $DRY_RUN"

    init_deferred

    ITERATION=0
    local last_action=""
    local repeat_count=0
    local MAX_REPEAT=3

    while [[ $ITERATION -lt $MAX_ITERATIONS ]]; do
        ITERATION=$((ITERATION + 1))

        log_info "=== Iteration $ITERATION of $MAX_ITERATIONS ==="

        # Check if milestone is complete
        if is_milestone_complete; then
            log_success "Milestone complete!"
            break
        fi

        # Get current phase and status
        local current_phase
        current_phase=$(get_current_phase)

        if [[ "$current_phase" == "COMPLETE" ]]; then
            log_success "All phases complete!"
            break
        fi

        if [[ "$current_phase" == "ERROR" ]]; then
            log_error "No phases found in ROADMAP.md"
            break
        fi

        local status
        status=$(get_phase_status "$current_phase")

        log_phase "Phase $current_phase - Status: $status"

        # Determine next action
        local action
        action=$(determine_next_action "$current_phase")

        if [[ "$action" == "NEXT_PHASE" ]]; then
            log_info "Phase $current_phase verified, moving to next phase"
            last_action=""
            repeat_count=0
            continue
        fi

        if [[ "$action" == "ERROR" ]]; then
            log_error "Could not determine action for phase $current_phase"
            break
        fi

        # Stuck detection: break if the same action repeats without progress
        if [[ "$action" == "$last_action" ]]; then
            repeat_count=$((repeat_count + 1))
            if [[ $repeat_count -ge $MAX_REPEAT ]]; then
                log_error "Stuck: '$action' repeated $MAX_REPEAT times without status change"
                log_error "Phase $current_phase status remains '$status' - manual intervention needed"
                break
            fi
            log_warn "Repeat $repeat_count/$MAX_REPEAT for action: $action"
        else
            repeat_count=1
            last_action="$action"
        fi

        log_info "Action: /gsd:$action"

        # Run the GSD command
        if ! run_gsd_command "$action"; then
            log_error "Command failed, stopping"
            break
        fi

        # Small delay between iterations to avoid hammering
        sleep 1
    done

    # Final summary
    echo ""
    log_info "=== Ralph-GSD Summary ==="
    log_info "Iterations completed: $ITERATION"

    if is_milestone_complete; then
        log_success "Milestone fully completed!"
    else
        local current_phase
        current_phase=$(get_current_phase)
        local status
        status=$(get_phase_status "$current_phase")
        log_warn "Stopped at phase $current_phase (status: $status)"
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
}

#=============================================================================
# Entry Point
#=============================================================================

main() {
    parse_args "$@"
    main_loop
}

main "$@"
