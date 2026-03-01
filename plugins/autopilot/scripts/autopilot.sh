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

VERSION="1.2.0"
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

# Evolve mode options
MAX_MILESTONES=0       # 0 = unlimited
EVOLVE_FOCUS=""        # comma-separated focus areas

# Cost/budget options
BUDGET_LIMIT=""        # empty = no limit (in USD)
PHASE_TIMEOUT=1800     # seconds per claude invocation (default: 30min)


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
            --milestones)      MAX_MILESTONES="$2"; shift 2 ;;
            --focus)           EVOLVE_FOCUS="$2"; shift 2 ;;
            --budget)          BUDGET_LIMIT="$2"; shift 2 ;;
            --phase-timeout)   PHASE_TIMEOUT="$2"; shift 2 ;;
            --help)            show_help; exit 0 ;;
            *)                 log_error "Unknown option: $1"; exit 1 ;;
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
    --milestones N         Max milestones to complete in evolve mode (default: unlimited)
    --focus AREAS          Comma-separated focus areas for evolve strategist
                           e.g., "testing,security" or "performance,reliability"
    --budget DOLLARS       Stop when estimated cost exceeds this USD amount (default: no limit)
                           e.g., --budget 5.00
    --phase-timeout SECS   Timeout per claude invocation in seconds (default: 1800)
                           e.g., --phase-timeout 3600
    --resume               Resume from existing progress state
    --dry-run              Show what would happen without executing
    --help                 Show this help

MODES (set in .autopilot/mission.json):
    mission      Default task-based loop
    improve      Codebase health scan and fix
    execute      GSD phase execution (requires .planning/)
    research     Deep research mode
    evolve       Autonomous milestone generation and execution
                 Analyzes codebase → generates milestones → executes each via GSD → repeats
    build-saas   Fully autonomous SaaS product builder
                 Phases: market research → scaffold → features → marketing → polish → evolve
    marketing    Iterative content generation loop
                 Generates blog posts, social media, pSEO pages continuously
EOF
}

#=============================================================================
# Learning — Structured Cross-Iteration Knowledge
#=============================================================================

LEARNING_FILE=""

learning_init() {
    LEARNING_FILE="$AUTOPILOT_DIR/learning.json"
    if [[ ! -f "$LEARNING_FILE" ]]; then
        cat > "$LEARNING_FILE" << 'EOF'
{
  "iterations": [],
  "patterns": {
    "recurring_errors": [],
    "successful_approaches": [],
    "failed_approaches": []
  }
}
EOF
        log_info "Initialized learning.json"
    fi
}

# Returns a compact summary of recent learning to inject into iteration prompts
learning_read_context() {
    [[ -z "$LEARNING_FILE" ]] && LEARNING_FILE="$AUTOPILOT_DIR/learning.json"
    [[ ! -f "$LEARNING_FILE" ]] && return 0

    python3 - "$LEARNING_FILE" << 'PYEOF' 2>/dev/null || true
import json, sys

data = json.load(open(sys.argv[1]))
iterations = data.get("iterations", [])
patterns = data.get("patterns", {})

if not iterations and not patterns.get("recurring_errors"):
    print("No prior iterations recorded.")
    sys.exit(0)

# Last 3 iterations summary
recent = iterations[-3:]
if recent:
    print("### Recent Iterations (last {}):".format(len(recent)))
    for it in recent:
        outcome = it.get("outcome", "unknown")
        task = it.get("task", "?")[:80]
        dur = it.get("duration_seconds", 0)
        print(f"- Iter {it.get('iteration','?')}: [{outcome}] {task} ({dur}s)")
        for w in it.get("what_worked", [])[:2]:
            print(f"  + worked: {w}")
        for f in it.get("what_failed", [])[:2]:
            print(f"  - failed: {f}")

# Recurring errors with resolutions
rec_errors = patterns.get("recurring_errors", [])
if rec_errors:
    print("\n### Recurring Errors (know these):")
    for e in rec_errors[:5]:
        print(f"- [{e.get('count',0)}x] {e.get('error','?')}")
        if e.get("last_resolution"):
            print(f"  Resolution: {e['last_resolution']}")

# Successful approaches
success = patterns.get("successful_approaches", [])
if success:
    print("\n### Proven Approaches (reuse these):")
    for s in success[:5]:
        print(f"- {s}")

# Failed approaches
failed = patterns.get("failed_approaches", [])
if failed:
    print("\n### Known Dead Ends (avoid these):")
    for f in failed[:5]:
        print(f"- {f}")
PYEOF
}

# Aggregate patterns from iterations array — promotes recurring items to patterns
aggregate_patterns() {
    [[ -z "$LEARNING_FILE" ]] && LEARNING_FILE="$AUTOPILOT_DIR/learning.json"
    [[ ! -f "$LEARNING_FILE" ]] && return 0

    python3 - "$LEARNING_FILE" << 'PYEOF' 2>/dev/null || true
import json, sys
from collections import Counter

path = sys.argv[1]
data = json.load(open(path))
iterations = data.get("iterations", [])
patterns = data.get("patterns", {"recurring_errors": [], "successful_approaches": [], "failed_approaches": []})

# Count errors across all iterations
error_counts = Counter()
error_resolutions = {}
for it in iterations:
    for e in it.get("errors_encountered", []):
        msg = e.get("error", "")
        if msg:
            error_counts[msg] += 1
            if e.get("resolution"):
                error_resolutions[msg] = e["resolution"]

# Promote errors seen 2+ times
existing_errors = {e["error"] for e in patterns["recurring_errors"]}
for msg, count in error_counts.items():
    if count >= 2 and msg not in existing_errors:
        patterns["recurring_errors"].append({
            "error": msg,
            "count": count,
            "last_resolution": error_resolutions.get(msg, "")
        })
    elif count >= 2:
        # Update count on existing
        for e in patterns["recurring_errors"]:
            if e["error"] == msg:
                e["count"] = count
                if error_resolutions.get(msg):
                    e["last_resolution"] = error_resolutions[msg]
                break

# Count successful approaches
approach_success = Counter()
for it in iterations:
    if it.get("outcome") in ("success", "partial"):
        for a in it.get("what_worked", []):
            if a:
                approach_success[a] += 1

existing_success = set(patterns["successful_approaches"])
for approach, count in approach_success.items():
    if count >= 2 and approach not in existing_success:
        patterns["successful_approaches"].append(approach)

# Count failed approaches
approach_failed = Counter()
for it in iterations:
    if it.get("outcome") in ("failure", "partial"):
        for a in it.get("what_failed", []):
            if a:
                approach_failed[a] += 1

existing_failed = set(patterns["failed_approaches"])
for approach, count in approach_failed.items():
    if count >= 2 and approach not in existing_failed:
        patterns["failed_approaches"].append(approach)

data["patterns"] = patterns
json.dump(data, open(path, "w"), indent=2)
print("Patterns aggregated.")
PYEOF
    log_info "Learning patterns aggregated"
}

# Generate handoff.md from learning.json (falls back to existing handoff.md if no learning data)
generate_handoff_from_learning() {
    [[ -z "$LEARNING_FILE" ]] && LEARNING_FILE="$AUTOPILOT_DIR/learning.json"

    if [[ ! -f "$LEARNING_FILE" ]]; then
        # No learning.json — leave handoff.md as-is (backward compat)
        return 0
    fi

    python3 - "$LEARNING_FILE" "$AUTOPILOT_DIR/handoff.md" << 'PYEOF' 2>/dev/null || true
import json, sys, os

learning_path = sys.argv[1]
handoff_path = sys.argv[2]

data = json.load(open(learning_path))
iterations = data.get("iterations", [])
patterns = data.get("patterns", {})

if not iterations:
    # No structured data yet — don't overwrite existing handoff.md
    sys.exit(0)

last = iterations[-1]
lines = []
lines.append("# Handoff Notes")
lines.append("")
lines.append("## Current Task")
lines.append(last.get("task", "[unknown task]"))
lines.append("")
lines.append("## What's Done")
for w in last.get("what_worked", []):
    lines.append(f"- {w}")
if not last.get("what_worked"):
    lines.append("- (no items recorded)")
lines.append("")
lines.append("## What's Left")
lines.append("- (see progress.json for next pending task)")
lines.append("")
lines.append("## Key Context")
decisions = last.get("decisions_made", [])
for d in decisions:
    lines.append(f"- AUTO-DECIDED: {d.get('decision','?')} — because {d.get('reason','?')}")
if not decisions:
    lines.append("- (no decisions recorded this iteration)")
lines.append("")
lines.append("## Failed Approaches")
for f in last.get("what_failed", []):
    lines.append(f"- {f} — DO NOT retry")
if not last.get("what_failed"):
    lines.append("- (none this iteration)")
lines.append("")
lines.append("## Files Modified")
for f in last.get("files_modified", []):
    lines.append(f"- `{f}`")
if not last.get("files_modified"):
    lines.append("- (none recorded)")
lines.append("")
lines.append("## State")
lines.append(f"- Iteration: {last.get('iteration','?')}")
lines.append(f"- Outcome: {last.get('outcome','unknown')}")
lines.append(f"- Duration: {last.get('duration_seconds', 0)}s")
commits = last.get("commits", [])
lines.append(f"- Commits: {', '.join(commits) if commits else 'none'}")
lines.append("")

# Recurring error patterns
rec_errors = patterns.get("recurring_errors", [])
if rec_errors:
    lines.append("## Recurring Errors (from learning.json)")
    for e in rec_errors[:5]:
        lines.append(f"- [{e.get('count',0)}x] {e.get('error','?')}")
        if e.get("last_resolution"):
            lines.append(f"  Resolution: {e['last_resolution']}")
    lines.append("")

with open(handoff_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print("handoff.md generated from learning.json")
PYEOF
}

#=============================================================================
# Cost / Budget Tracking
#=============================================================================

# Source external cost tracker if available (provides additional helpers)
[[ -f "$HOME/.claude/scripts/cost-tracker.sh" ]] && source "$HOME/.claude/scripts/cost-tracker.sh" || true

COSTS_FILE=""

cost_init() {
    COSTS_FILE="$AUTOPILOT_DIR/costs.json"
    if [[ ! -f "$COSTS_FILE" ]]; then
        cat > "$COSTS_FILE" << 'EOF'
{
  "iterations": [],
  "total_input_tokens": 0,
  "total_output_tokens": 0,
  "estimated_cost_usd": 0
}
EOF
        log_info "Initialized costs.json"
    fi
}

# track_iteration_cost <log_file_path>
# Parses token usage from a claude --verbose log and appends to costs.json
track_iteration_cost() {
    local log_file="$1"
    [[ -z "$COSTS_FILE" ]] && COSTS_FILE="$AUTOPILOT_DIR/costs.json"
    [[ ! -f "$COSTS_FILE" ]] && cost_init
    [[ ! -f "$log_file"   ]] && return 0

    python3 - "$log_file" "$COSTS_FILE" << 'PYEOF' 2>/dev/null || true
import json, sys, re, os
from datetime import datetime, timezone

log_path  = sys.argv[1]
cost_path = sys.argv[2]

log_text = open(log_path).read()

# Claude --verbose outputs token counts in various formats; try several patterns
input_tokens  = 0
output_tokens = 0

# Pattern 1: JSON-style  "input_tokens": 1234
m = re.search(r'"input_tokens"\s*:\s*(\d+)', log_text)
if m:
    input_tokens = int(m.group(1))

m = re.search(r'"output_tokens"\s*:\s*(\d+)', log_text)
if m:
    output_tokens = int(m.group(1))

# Pattern 2: plain text  "Input tokens: 1234"
if not input_tokens:
    m = re.search(r'[Ii]nput\s+tokens?[:\s]+(\d+)', log_text)
    if m:
        input_tokens = int(m.group(1))

if not output_tokens:
    m = re.search(r'[Oo]utput\s+tokens?[:\s]+(\d+)', log_text)
    if m:
        output_tokens = int(m.group(1))

if not input_tokens and not output_tokens:
    sys.exit(0)  # nothing to record

# Detect model from log (default to Sonnet pricing)
# Sonnet: $3/$15 per MTok in/out
# Opus:   $15/$75 per MTok in/out
# Haiku:  $0.80/$4 per MTok in/out
if 'opus' in log_text.lower():
    in_price, out_price = 15.0, 75.0
elif 'haiku' in log_text.lower():
    in_price, out_price = 0.80, 4.0
else:
    in_price, out_price = 3.0, 15.0  # Sonnet default

iteration_cost = (input_tokens / 1_000_000 * in_price) + (output_tokens / 1_000_000 * out_price)

data = json.load(open(cost_path))
data["iterations"].append({
    "log": os.path.basename(log_path),
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "input_tokens":  input_tokens,
    "output_tokens": output_tokens,
    "cost_usd":      round(iteration_cost, 6)
})
data["total_input_tokens"]  += input_tokens
data["total_output_tokens"] += output_tokens
data["estimated_cost_usd"]  = round(data["estimated_cost_usd"] + iteration_cost, 6)

json.dump(data, open(cost_path, "w"), indent=2)
print(f"Cost tracked: ${iteration_cost:.4f} (in={input_tokens}, out={output_tokens})")
PYEOF
    log_info "Cost tracked for $(basename "$log_file")"
}

# check_budget — returns 1 (stop) if budget exceeded, 0 (continue) otherwise
check_budget() {
    [[ -z "$BUDGET_LIMIT" ]] && return 0  # no limit set
    [[ -z "$COSTS_FILE"   ]] && COSTS_FILE="$AUTOPILOT_DIR/costs.json"
    [[ ! -f "$COSTS_FILE" ]] && return 0

    python3 - "$COSTS_FILE" "$BUDGET_LIMIT" << 'PYEOF' 2>/dev/null
import json, sys
data  = json.load(open(sys.argv[1]))
limit = float(sys.argv[2])
spent = data.get("estimated_cost_usd", 0)
if spent >= limit:
    print(f"BUDGET_EXCEEDED: ${spent:.4f} spent of ${limit:.2f} limit")
    sys.exit(1)
else:
    print(f"Budget OK: ${spent:.4f} of ${limit:.2f}")
    sys.exit(0)
PYEOF
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        local spent
        spent=$(python3 -c "import json; d=json.load(open('$COSTS_FILE')); print(d.get('estimated_cost_usd',0))" 2>/dev/null || echo "?")
        log_warn "BUDGET EXCEEDED: \$$spent spent of \$$BUDGET_LIMIT limit — creating STOP file"
        touch "$AUTOPILOT_DIR/STOP"
        return 1
    fi
    return 0
}

#=============================================================================
# Cross-Project Knowledge
#=============================================================================

GLOBAL_KNOWLEDGE_DIR="$HOME/.claude/autopilot-knowledge"

# Read global knowledge patterns relevant to current project
read_global_knowledge() {
    local patterns_file="$GLOBAL_KNOWLEDGE_DIR/patterns.json"
    [[ ! -f "$patterns_file" ]] && return 0

    python3 - "$patterns_file" << 'PYEOF' 2>/dev/null || true
import json, sys
data = json.load(open(sys.argv[1]))
if not data:
    sys.exit(0)

print("### Global Knowledge (from previous projects):")
for category, entries in data.items():
    if not entries:
        continue
    print(f"\n**{category}**:")
    if isinstance(entries, list):
        for e in entries[:5]:
            print(f"- {e}")
    elif isinstance(entries, dict):
        for k, v in list(entries.items())[:5]:
            print(f"- {k}: {v}")
PYEOF
}

# write_global_knowledge <category> <key> <value>
# Appends a pattern to ~/.claude/autopilot-knowledge/<category>.json
write_global_knowledge() {
    local category="$1" key="$2" value="$3"
    mkdir -p "$GLOBAL_KNOWLEDGE_DIR"
    local cat_file="$GLOBAL_KNOWLEDGE_DIR/${category}.json"

    python3 - "$cat_file" "$key" "$value" << 'PYEOF' 2>/dev/null || true
import json, sys, os
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except Exception:
        data = {}
if not isinstance(data, dict):
    data = {}
data[key] = val
json.dump(data, open(path, "w"), indent=2)
print(f"Global knowledge written: {key}")
PYEOF

    # Also update the central patterns.json
    local patterns_file="$GLOBAL_KNOWLEDGE_DIR/patterns.json"
    python3 - "$patterns_file" "$category" "$key" "$value" << 'PYEOF' 2>/dev/null || true
import json, sys, os
path, cat, key, val = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except Exception:
        data = {}
if cat not in data:
    data[cat] = {}
if not isinstance(data[cat], dict):
    data[cat] = {}
data[cat][key] = val
json.dump(data, open(path, "w"), indent=2)
PYEOF
    log_info "Global knowledge written: [$category] $key"
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
# Evolve Mode — Milestone State Management
#=============================================================================

MILESTONES_FILE=""

evolve_init_state() {
    MILESTONES_FILE="$AUTOPILOT_DIR/milestones.json"
    if [[ ! -f "$MILESTONES_FILE" ]]; then
        cat > "$MILESTONES_FILE" << 'EOF'
{
  "milestones": [],
  "currentMilestone": null,
  "completedCount": 0,
  "generatedAt": null,
  "strategy": null
}
EOF
        log_info "Initialized milestones.json"
    fi
}

evolve_get_completed_count() {
    grep -c '"status"[[:space:]]*:[[:space:]]*"completed"' "$MILESTONES_FILE" 2>/dev/null || echo "0"
}

evolve_get_pending_count() {
    grep -c '"status"[[:space:]]*:[[:space:]]*"pending"' "$MILESTONES_FILE" 2>/dev/null || echo "0"
}

evolve_has_milestones() {
    local pending
    pending=$(evolve_get_pending_count)
    [[ "$pending" -gt 0 ]]
}

evolve_should_stop() {
    [[ -f "$AUTOPILOT_DIR/STOP" ]] && { log_info "Stop signal detected"; return 0; }
    local status; status=$(get_status)
    [[ "$status" == "complete" || "$status" == "stopped" ]] && return 0
    [[ $ITERATION -ge $MAX_ITERATIONS ]] && { log_warn "Max iterations ($MAX_ITERATIONS)"; return 0; }
    local elapsed=$(( ($(date +%s) - START_TIME) / 3600 ))
    [[ $elapsed -ge $MAX_HOURS ]] && { log_warn "Time limit (${MAX_HOURS}h)"; return 0; }
    if [[ $MAX_MILESTONES -gt 0 ]]; then
        local done; done=$(evolve_get_completed_count)
        [[ $done -ge $MAX_MILESTONES ]] && { log_success "Max milestones reached ($MAX_MILESTONES)"; return 0; }
    fi
    return 1
}

# Extract next pending milestone id and title from milestones.json (no jq)
evolve_get_next_milestone() {
    # Find first milestone with "status": "pending" — extract its id and title
    python3 - "$MILESTONES_FILE" << 'PYEOF' 2>/dev/null || echo ""
import json, sys
data = json.load(open(sys.argv[1]))
for m in data.get("milestones", []):
    if m.get("status") == "pending":
        print(f'{m["id"]}|||{m["title"]}|||{m["description"]}')
        break
PYEOF
}

# Mark a milestone as active/completed in milestones.json
evolve_update_milestone_status() {
    local id=$1 new_status=$2 extra_field=${3:-} extra_value=${4:-}
    python3 - "$MILESTONES_FILE" "$id" "$new_status" "$extra_field" "$extra_value" << 'PYEOF' 2>/dev/null
import json, sys
from datetime import datetime, timezone

path, mid, status, ef, ev = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
data = json.load(open(path))
for m in data["milestones"]:
    if m["id"] == mid:
        m["status"] = status
        if status == "active":
            m["startedAt"] = datetime.now(timezone.utc).isoformat()
        elif status == "completed":
            m["completedAt"] = datetime.now(timezone.utc).isoformat()
            data["completedCount"] = data.get("completedCount", 0) + 1
            data["currentMilestone"] = None
        if ef:
            m[ef] = ev
        break
json.dump(data, open(path, "w"), indent=2)
PYEOF
    log_info "Milestone $id → $new_status"
}

evolve_set_gsd_project() {
    local id=$1 gsd_path=$2
    python3 - "$MILESTONES_FILE" "$id" "$gsd_path" << 'PYEOF' 2>/dev/null
import json, sys
path, mid, gsd = sys.argv[1], int(sys.argv[2]), sys.argv[3]
data = json.load(open(path))
for m in data["milestones"]:
    if m["id"] == mid:
        m["gsdProject"] = gsd
        break
json.dump(data, open(path, "w"), indent=2)
PYEOF
}

# Build the strategist prompt
build_strategist_prompt() {
    local is_reeval=${1:-false}
    local focus_clause=""
    [[ -n "$EVOLVE_FOCUS" ]] && focus_clause="Focus only on these areas: $EVOLVE_FOCUS"

    local completed; completed=$(evolve_get_completed_count)
    local milestones_content; milestones_content=$(cat "$MILESTONES_FILE")

    cat << PROMPT
## AUTOPILOT EVOLVE — Strategist Agent

You are the Autopilot Strategist. Your job is to analyze this codebase and generate prioritized milestones.

## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

**Project root**: $PROJECT_DIR
**Is re-evaluation**: $is_reeval
**Milestones completed so far**: $completed
$focus_clause

### Current milestones.json
$milestones_content

### Your Task

Follow the Strategist Agent protocol:
1. Read CLAUDE.md, README.md, package.json (or equivalent) in $PROJECT_DIR
2. Run \`git log --oneline -20\` and \`git diff --stat HEAD~5 HEAD\`
3. Scan codebase health across: tests, error handling, types, security, performance, observability, DX, architecture
4. **On first run** (milestones completed = 0 and no pending milestones): run the research phase — use /gsd:research-phase or equivalent to deeply explore the codebase before generating milestones. This ensures milestones are grounded in actual code state, not assumptions.
5. Generate 5-10 concrete, achievable milestones
6. Write updated milestones to $AUTOPILOT_DIR/milestones.json
7. Append strategist summary to $AUTOPILOT_DIR/handoff.md

Rules:
- Preserve ALL milestones with "status": "completed" exactly as-is
- Do NOT regenerate milestones that are already "pending" unless they're now obsolete
- Be opinionated: generate milestones a senior engineer would be proud of
- Each milestone description must be specific enough to hand directly to /gsd:new-milestone

When done, output: AUTOPILOT_STATUS: STRATEGIST_COMPLETE
PROMPT
}

# Run the strategist to generate/refresh milestones
run_strategist() {
    local is_reeval=${1:-false}
    local prompt
    prompt=$(build_strategist_prompt "$is_reeval")

    log_phase "Strategist — $([ "$is_reeval" == "true" ] && echo "Re-evaluating" || echo "Generating") milestones"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run strategist agent"
        return 0
    fi

    local strat_log="$AUTOPILOT_DIR/iterations/strategist-${ITERATION}.log"
    mkdir -p "$AUTOPILOT_DIR/iterations"

    cd "$PROJECT_DIR"
    local strat_exit=0
    timeout "$PHASE_TIMEOUT" claude -p "$prompt" \
        --dangerously-skip-permissions \
        --allowedTools '*' \
        2>&1 | tee "$strat_log" || strat_exit=$?

    if [[ $strat_exit -eq 124 ]]; then
        log_warn "TIMEOUT: Strategist exceeded ${PHASE_TIMEOUT}s limit — using whatever milestones were generated"
    elif ! grep -q "AUTOPILOT_STATUS: STRATEGIST_COMPLETE" "$strat_log" 2>/dev/null; then
        log_warn "Strategist did not signal completion — continuing anyway"
    fi

    track_iteration_cost "$strat_log"

    local pending; pending=$(evolve_get_pending_count)
    log_info "Strategist complete — $pending milestones pending"
}

# Build the GSD new-milestone prompt for a given milestone
build_new_milestone_prompt() {
    local title=$1 description=$2

    cat << PROMPT
## AUTOPILOT EVOLVE — New Milestone Setup

You are setting up a new GSD milestone inside the Autopilot evolve loop.

**Project root**: $PROJECT_DIR
**Milestone title**: $title
**Milestone description**: $description

### Your Task

Run the skill /gsd:new-milestone with this milestone as input.

The skill will:
1. Create a .planning/ directory (or add to existing one)
2. Generate a ROADMAP.md with phases
3. Set up the milestone structure

After /gsd:new-milestone completes, report back:
- The path to the ROADMAP.md that was created
- How many phases were defined

Output the planning directory path as:
MILESTONE_PLANNING_PATH: <absolute path to .planning/ directory>

Then output: AUTOPILOT_STATUS: MILESTONE_SETUP_COMPLETE
PROMPT
}

# Initialize a GSD milestone for the given milestone entry
run_new_milestone() {
    local id=$1 title=$2 description=$3
    local prompt
    prompt=$(build_new_milestone_prompt "$title" "$description")

    log_phase "Setting up GSD milestone: $title"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run /gsd:new-milestone for: $title"
        return 0
    fi

    local setup_log="$AUTOPILOT_DIR/iterations/milestone-setup-${id}.log"
    mkdir -p "$AUTOPILOT_DIR/iterations"

    cd "$PROJECT_DIR"
    local setup_exit=0
    timeout "$PHASE_TIMEOUT" claude -p "$prompt" \
        --dangerously-skip-permissions \
        --allowedTools '*' \
        2>&1 | tee "$setup_log" || setup_exit=$?

    if [[ $setup_exit -eq 124 ]]; then
        log_warn "TIMEOUT: Milestone setup exceeded ${PHASE_TIMEOUT}s limit — proceeding with partial setup"
    fi

    track_iteration_cost "$setup_log"

    # Extract planning path from output
    local planning_path
    planning_path=$(grep "MILESTONE_PLANNING_PATH:" "$setup_log" 2>/dev/null | tail -1 | sed 's/MILESTONE_PLANNING_PATH: *//')

    if [[ -n "$planning_path" ]]; then
        evolve_set_gsd_project "$id" "$planning_path"
        log_info "GSD project at: $planning_path"
    else
        log_warn "Could not extract planning path — using default .planning/"
        evolve_set_gsd_project "$id" "$PROJECT_DIR/.planning"
    fi
}

#=============================================================================
# GSD Execute Mode — Delegation to ralph-gsd.sh
#=============================================================================

# Locate ralph-gsd.sh dynamically across common plugin install locations
find_ralph_gsd_script() {
    local paths=(
        "$HOME/.claude/plugins/marketplaces/george-plugins/plugins/ralph-gsd/scripts/ralph-gsd.sh"
        "$HOME/.claude/plugins/ralph-gsd/scripts/ralph-gsd.sh"
    )
    for p in "${paths[@]}"; do
        if [[ -f "$p" ]]; then echo "$p"; return 0; fi
    done
    log_error "ralph-gsd.sh not found in any known plugin location"
    return 1
}

# Parse phases_complete and phases_total from a RALPH_EXIT line in a log file
parse_ralph_exit() {
    local log_file="$1"
    local field="$2"  # "phases_complete" or "phases_total"
    grep "^RALPH_EXIT:" "$log_file" 2>/dev/null | tail -1 | grep -oE "${field}=[0-9]+" | cut -d= -f2 || echo "0"
}

# GSD Execute Mode Main Loop
#
# Architecture: This function is a thin wrapper around ralph-gsd.sh.
# Rather than reimplementing GSD phase detection + action mapping (which
# ralph-gsd.sh already does), we delegate the entire state machine to it
# and handle only the exit codes here.
#
# Exit code contract (from ralph-gsd.sh):
#   0 = complete — all phases verified
#   1 = error    — unrecoverable failure
#   2 = stopped  — STOP file detected, graceful shutdown
#   3 = deadlock — no phases can make progress
#
# In evolve mode, gsd_main_loop() is called between Strategist runs;
# return status propagates to evolve_main_loop() for milestone bookkeeping.
gsd_main_loop() {
    log_info "GSD Execute Mode — delegating to ralph-gsd.sh"

    # Verify .planning/ exists
    if [[ ! -d "$PROJECT_DIR/.planning" ]]; then
        log_error "No .planning/ directory. Run /gsd:new-project first."
        return 1
    fi

    local ralph_gsd_path
    ralph_gsd_path=$(find_ralph_gsd_script) || return 1

    local ralph_log="$AUTOPILOT_DIR/ralph-gsd.log"
    local stop_file="$AUTOPILOT_DIR/STOP"

    # Build flags
    local ralph_flags=(
        --project-dir "$PROJECT_DIR"
        --stop-file   "$stop_file"
        --log-file    "$ralph_log"
        --resume
    )

    [[ "$SKIP_DISCUSS" == true ]] && ralph_flags+=(--skip-discuss)
    [[ "$DRY_RUN"      == true ]] && ralph_flags+=(--dry-run)

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: ralph-gsd.sh ${ralph_flags[*]}"
        return 0
    fi

    log_info "Launching ralph-gsd.sh..."
    local exit_code=0
    bash "$ralph_gsd_path" "${ralph_flags[@]}" 2>&1 | tee -a "$AUTOPILOT_DIR/loop.log" || exit_code=$?

    # Parse machine-readable summary from ralph-gsd log
    local phases_complete phases_total
    phases_complete=$(parse_ralph_exit "$ralph_log" "phases_complete")
    phases_total=$(parse_ralph_exit    "$ralph_log" "phases_total")
    log_info "ralph-gsd finished: phases $phases_complete/$phases_total"

    case $exit_code in
        0)
            # Complete — all phases verified
            log_success "GSD milestone complete (all $phases_total phases verified)"
            sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "complete"/' "$AUTOPILOT_DIR/mission.json"
            return 0
            ;;
        1)
            # Error — retry once with --resume, then give up
            log_error "ralph-gsd reported an error — retrying once with --resume"
            local retry_code=0
            bash "$ralph_gsd_path" "${ralph_flags[@]}" 2>&1 | tee -a "$AUTOPILOT_DIR/loop.log" || retry_code=$?
            if [[ $retry_code -ne 0 ]]; then
                log_error "ralph-gsd failed after retry (exit $retry_code) — marking milestone failed"
                sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "error"/' "$AUTOPILOT_DIR/mission.json"
                return 1
            fi
            log_success "GSD retry succeeded"
            return 0
            ;;
        2)
            # Stopped — propagate stop signal to autopilot outer loop
            log_info "ralph-gsd stopped (STOP file) — propagating to autopilot"
            # Ensure STOP file exists so autopilot's outer should_stop() fires
            touch "$AUTOPILOT_DIR/STOP"
            return 2
            ;;
        3)
            # Deadlock — behavior differs by calling context:
            #   evolve mode: log warning, return non-zero so milestone is skipped
            #   execute mode: log error and return
            log_warn "ralph-gsd deadlock: no phases can make progress (phases $phases_complete/$phases_total complete)"
            return 3
            ;;
        *)
            log_error "ralph-gsd exited with unexpected code $exit_code"
            return 1
            ;;
    esac
}

#=============================================================================
# Evolve Mode Main Loop
#=============================================================================

evolve_main_loop() {
    log_info "Evolve Mode — autonomous milestone generation and execution"

    evolve_init_state

    local milestone_count=0
    local first_run=true

    while ! evolve_should_stop; do
        # ── Phase A: Generate / refresh milestones ──────────────────────────
        local pending; pending=$(evolve_get_pending_count)

        if [[ "$pending" -eq 0 ]]; then
            # Need new milestones (first run or all exhausted)
            local is_reeval="false"
            [[ "$first_run" == "false" ]] && is_reeval="true"

            run_strategist "$is_reeval"
            first_run=false

            pending=$(evolve_get_pending_count)
            if [[ "$pending" -eq 0 ]]; then
                log_success "Strategist found no new milestones — evolve complete"
                sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "complete"/' "$AUTOPILOT_DIR/mission.json"
                break
            fi
        fi

        # ── Phase B: Pick next milestone ────────────────────────────────────
        local next_info
        next_info=$(evolve_get_next_milestone)

        if [[ -z "$next_info" ]]; then
            log_warn "No next milestone found despite pending count > 0 — check milestones.json"
            break
        fi

        local ms_id ms_title ms_desc
        ms_id=$(echo "$next_info" | cut -d'|' -f1)
        ms_title=$(echo "$next_info" | cut -d'|' -f4)
        ms_desc=$(echo "$next_info" | cut -d'|' -f7-)

        milestone_count=$((milestone_count + 1))
        log_phase "Milestone $milestone_count: $ms_title (id=$ms_id)"

        # Mark active
        evolve_update_milestone_status "$ms_id" "active"

        # ── Phase C: Initialize GSD milestone ───────────────────────────────
        run_new_milestone "$ms_id" "$ms_title" "$ms_desc"

        if evolve_should_stop; then break; fi

        # ── Phase D: Execute all GSD phases for this milestone ──────────────
        log_info "Starting GSD phase execution for milestone: $ms_title"
        local gsd_rc=0
        gsd_main_loop || gsd_rc=$?

        # Handle ralph-gsd exit codes from gsd_main_loop
        case $gsd_rc in
            0)
                # Success — fall through to Phase E
                ;;
            2)
                # Stopped — propagate and exit evolve loop immediately
                log_info "Milestone halted by STOP signal — exiting evolve loop"
                break
                ;;
            3)
                # Deadlock — skip this milestone, continue evolve loop
                log_warn "Milestone '$ms_title' deadlocked — skipping, continuing to next"
                evolve_update_milestone_status "$ms_id" "completed" "skippedReason" "deadlock"
                continue
                ;;
            *)
                # Error — log but still continue to next milestone
                log_error "GSD execution failed (rc=$gsd_rc) for milestone '$ms_title' — continuing to next"
                evolve_update_milestone_status "$ms_id" "completed" "skippedReason" "error"
                continue
                ;;
        esac

        # ── Phase E: Mark milestone complete, re-evaluate ───────────────────
        evolve_update_milestone_status "$ms_id" "completed"
        local done_count; done_count=$(evolve_get_completed_count)
        log_success "Milestone $milestone_count complete! (Total completed: $done_count)"

        # Write milestone completion pattern to global cross-project knowledge
        write_global_knowledge "milestones" "$ms_title" "completed in project: $PROJECT_DIR"
        check_budget || break

        if evolve_should_stop; then break; fi

        # Re-run strategist to reprioritize remaining milestones
        # (codebase changed — some pending ideas may be obsolete or new ones emerged)
        log_info "Re-evaluating milestones after codebase change..."
        run_strategist "true"

        sleep 5
    done

    local total_done; total_done=$(evolve_get_completed_count)
    log_success "Evolve session ended — $total_done milestones completed"
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

    # Read cross-iteration learning context (compact summary)
    local learning_context
    learning_context=$(learning_read_context 2>/dev/null || echo "No prior learning data.")

    # Read cross-project global knowledge
    local global_context
    global_context=$(read_global_knowledge 2>/dev/null || echo "No global knowledge available.")

    # Build iteration start timestamp for learning record
    local iter_start_ts
    iter_start_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

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

### CROSS-ITERATION LEARNING
The following is structured knowledge accumulated from previous iterations.
Use it to avoid repeated mistakes and reuse successful approaches.

$learning_context

### GLOBAL PROJECT KNOWLEDGE
$global_context

## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

## Context Management
If you've used more than 30 tool calls in this iteration, save progress immediately and output:
AUTOPILOT_STATUS: CONTEXT_LIMIT
This prevents context window exhaustion.

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
- Update .autopilot/learning.json (REQUIRED — append your iteration record):
  Use python3 to append a new entry to the "iterations" array. Template:
  \`\`\`python
  import json, subprocess
  from datetime import datetime, timezone

  path = ".autopilot/learning.json"
  data = json.load(open(path))
  iter_start = "$iter_start_ts"  # set above by autopilot.sh

  # Get commit SHAs you made this iteration
  commits_raw = subprocess.run(["git", "log", "--oneline", "-5"], capture_output=True, text=True).stdout
  # Parse only the hashes you actually created (compare against what was in progress.json before)

  record = {
      "iteration": $iteration,
      "timestamp": iter_start,
      "task": "<task title you worked on>",
      "outcome": "success",  # or "failure" or "partial"
      "duration_seconds": int((datetime.now(timezone.utc) - datetime.fromisoformat(iter_start.replace('Z','+00:00'))).total_seconds()),
      "what_worked": ["<describe what approach succeeded>"],
      "what_failed": ["<describe any approach that didn't work>"],
      "errors_encountered": [{"error": "<error message>", "resolution": "<how you fixed it>"}],
      "decisions_made": [{"decision": "<chose X over Y>", "reason": "<why>"}],
      "files_modified": ["<list of files you touched>"],
      "commits": ["<sha>"]
  }
  data["iterations"].append(record)
  json.dump(data, open(path, "w"), indent=2)
  \`\`\`
  Fill in all fields accurately. If nothing failed, use empty lists — do NOT make up entries.
  If .autopilot/learning.json does not exist, create it with schema: {"iterations": [], "patterns": {"recurring_errors": [], "successful_approaches": [], "failed_approaches": []}}

### Step 7: Signal Completion
Output exactly: AUTOPILOT_STATUS: ITERATION_COMPLETE

---

## RULES

1. ONE TASK PER ITERATION. Do not try to do multiple tasks. Quality > quantity.
2. ALWAYS commit your work before finishing. Uncommitted work is lost work.
3. ALWAYS update progress.json AND learning.json. The next iteration depends on both.
4. If a task is unclear, make your best judgment and document the decision in learning.json.
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

    # Run Claude with fresh context (wrapped in timeout watchdog)
    local exit_code=0
    timeout "$PHASE_TIMEOUT" claude -p "$prompt" \
        --dangerously-skip-permissions \
        --verbose \
        --allowedTools '*' \
        2>&1 | tee "$iteration_log" || exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        log_warn "TIMEOUT: Claude process exceeded ${PHASE_TIMEOUT}s limit in iteration $ITERATION — treating as stuck iteration"
        echo "[AUTOPILOT] Iteration $ITERATION timed out after ${PHASE_TIMEOUT}s" >> "$iteration_log"
        # Don't stop — let the next iteration continue with remaining tasks
        aggregate_patterns
        generate_handoff_from_learning
        return 0
    fi

    # Track cost after invocation
    track_iteration_cost "$iteration_log"

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

    if grep -q "AUTOPILOT_STATUS: CONTEXT_LIMIT" "$iteration_log" 2>/dev/null; then
        log_warn "Context limit reached in iteration $ITERATION — progress saved, continuing next iteration"
        # Treat like ITERATION_COMPLETE: aggregate and handoff, then loop continues
    fi

    # Post-iteration learning: aggregate patterns and regenerate handoff.md
    aggregate_patterns
    generate_handoff_from_learning

    return 0
}

#=============================================================================
# Build-SaaS Mode — Fully Autonomous SaaS Product Builder
#=============================================================================

build_saas_main_loop() {
    local description="$1"

    log_info "Build-SaaS Mode — autonomous SaaS product builder"
    log_info "Product: $description"

    mkdir -p "$AUTOPILOT_DIR/iterations"

    # Phase 0: Market Research
    log_phase "=== PHASE 0: Market Research ==="
    local research_prompt="## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

You are a SaaS market researcher. Your task:
1. WebSearch for competitors in this space: $description
2. Identify 5-10 competitors. For each: features, pricing, user complaints
3. Categorize: Table Stakes (must-have), Differentiators (stand-out), Anti-Features (avoid)
4. Recommend: pricing model, MVP feature set, tech stack
5. Write findings to .autopilot/saas-research.md
Output: AUTOPILOT_STATUS: RESEARCH_COMPLETE"

    local phase0_log="$AUTOPILOT_DIR/iterations/phase-0-research.log"
    local phase0_exit=0
    timeout "$PHASE_TIMEOUT" claude -p "$research_prompt" \
        --dangerously-skip-permissions --verbose --allowedTools '*' \
        2>&1 | tee "$phase0_log" || phase0_exit=$?

    if [[ $phase0_exit -eq 124 ]]; then
        log_warn "TIMEOUT: Market research exceeded ${PHASE_TIMEOUT}s — proceeding with partial research"
    fi
    track_iteration_cost "$phase0_log"
    check_budget || return 1

    # Phase 1: Scaffold & Deploy
    log_phase "=== PHASE 1: Scaffold & Deploy ==="
    local scaffold_prompt="## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

You are a SaaS builder. Read .autopilot/saas-research.md for context.
1. Create a Next.js 15 project with: Tailwind CSS, TypeScript
2. Set up authentication with Clerk (use env vars from ~/.claude/account-inventory.json if exists)
3. Set up database with Convex
4. Set up payments with Stripe (products, prices, checkout)
5. Create landing page with value prop from research
6. Deploy to Vercel
7. Write deployment info to .autopilot/deployment.json
Product: $description
Output: AUTOPILOT_STATUS: SCAFFOLD_COMPLETE"

    local phase1_log="$AUTOPILOT_DIR/iterations/phase-1-scaffold.log"
    local phase1_exit=0
    timeout "$PHASE_TIMEOUT" claude -p "$scaffold_prompt" \
        --dangerously-skip-permissions --verbose --allowedTools '*' \
        2>&1 | tee "$phase1_log" || phase1_exit=$?

    if [[ $phase1_exit -eq 124 ]]; then
        log_warn "TIMEOUT: Scaffold phase exceeded ${PHASE_TIMEOUT}s"
    fi
    track_iteration_cost "$phase1_log"
    check_budget || return 1

    # Phase 2: Core Features (via GSD)
    log_phase "=== PHASE 2: Core Features ==="
    local features_prompt="## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

You are building a SaaS product. Read .autopilot/saas-research.md.
1. Run /gsd:new-milestone to create a milestone for building all core features
2. The roadmap should include: all Table Stakes features, top 3 Differentiators
3. Each feature should be a separate phase with proper dependencies
Product: $description
Output: AUTOPILOT_STATUS: MILESTONE_SETUP_COMPLETE"

    local phase2_log="$AUTOPILOT_DIR/iterations/phase-2-features-setup.log"
    local phase2_exit=0
    timeout $((PHASE_TIMEOUT * 2)) claude -p "$features_prompt" \
        --dangerously-skip-permissions --verbose --allowedTools '*' \
        2>&1 | tee "$phase2_log" || phase2_exit=$?

    if [[ $phase2_exit -eq 124 ]]; then
        log_warn "TIMEOUT: Features setup exceeded $((PHASE_TIMEOUT * 2))s"
    fi

    # Execute core features via ralph-gsd
    gsd_main_loop
    local gsd_exit=$?
    track_iteration_cost "$AUTOPILOT_DIR/ralph-gsd.log"
    check_budget || return 1
    [[ $gsd_exit -ne 0 ]] && log_warn "GSD exited with code $gsd_exit"

    # Phase 3: Marketing & SEO
    log_phase "=== PHASE 3: Marketing & SEO ==="
    local marketing_prompt="## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

You are a marketing agent for a SaaS product.
Read .autopilot/saas-research.md and the project README.
1. Generate 3 blog posts about the product (write to blog/ or content/ dir)
2. Generate SEO meta tags for all pages
3. Set up PostHog analytics (add tracking code)
4. Set up Sentry error monitoring
5. Generate Terms of Service and Privacy Policy (use legal-doc-generator agent if available)
6. Deploy updates to Vercel
Product: $description
Output: AUTOPILOT_STATUS: MARKETING_COMPLETE"

    local phase3_log="$AUTOPILOT_DIR/iterations/phase-3-marketing.log"
    local phase3_exit=0
    timeout "$PHASE_TIMEOUT" claude -p "$marketing_prompt" \
        --dangerously-skip-permissions --verbose --allowedTools '*' \
        2>&1 | tee "$phase3_log" || phase3_exit=$?

    if [[ $phase3_exit -eq 124 ]]; then
        log_warn "TIMEOUT: Marketing phase exceeded ${PHASE_TIMEOUT}s"
    fi
    track_iteration_cost "$phase3_log"
    check_budget || return 1

    # Phase 4: Polish & Launch
    log_phase "=== PHASE 4: Polish & Launch ==="
    local polish_prompt="## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

You are polishing a SaaS product for launch.
1. Check Sentry for any errors — fix them
2. Run Lighthouse audit — fix performance issues
3. Run accessibility audit — fix a11y issues
4. Check all user flows work end-to-end
5. Final deploy to Vercel
Output: AUTOPILOT_STATUS: POLISH_COMPLETE"

    local phase4_log="$AUTOPILOT_DIR/iterations/phase-4-polish.log"
    local phase4_exit=0
    timeout "$PHASE_TIMEOUT" claude -p "$polish_prompt" \
        --dangerously-skip-permissions --verbose --allowedTools '*' \
        2>&1 | tee "$phase4_log" || phase4_exit=$?

    if [[ $phase4_exit -eq 124 ]]; then
        log_warn "TIMEOUT: Polish phase exceeded ${PHASE_TIMEOUT}s"
    fi
    track_iteration_cost "$phase4_log"

    # Phase 5: Transition to evolve for continuous improvement
    log_phase "=== PHASE 5: Continuous Improvement ==="
    log_info "Build-SaaS complete. Transitioning to evolve mode for continuous improvement."
    sed -i 's/"mode"[[:space:]]*:[[:space:]]*"build-saas"/"mode": "evolve"/' "$AUTOPILOT_DIR/mission.json"
    evolve_main_loop
}

#=============================================================================
# Marketing Mode — Iterative Content Generation Loop
#=============================================================================

marketing_main_loop() {
    log_info "Marketing Mode — iterative content generation loop"

    mkdir -p "$AUTOPILOT_DIR/iterations"

    # Initialize content tracking in learning.json if not present
    if [[ -f "$AUTOPILOT_DIR/learning.json" ]]; then
        python3 - "$AUTOPILOT_DIR/learning.json" << 'PYEOF' 2>/dev/null || true
import json, sys
path = sys.argv[1]
data = json.load(open(path))
if "content_generated" not in data:
    data["content_generated"] = {
        "blog_posts": [],
        "social_posts": [],
        "seo_pages": []
    }
    json.dump(data, open(path, "w"), indent=2)
    print("Content tracking initialized in learning.json")
PYEOF
    fi

    local content_iteration=0

    while ! should_stop; do
        check_budget || break

        content_iteration=$((content_iteration + 1))
        ITERATION=$((ITERATION + 1))

        log_phase "Marketing Iteration $content_iteration"

        # Read what content has already been generated
        local content_history=""
        if [[ -f "$AUTOPILOT_DIR/learning.json" ]]; then
            content_history=$(python3 - "$AUTOPILOT_DIR/learning.json" << 'PYEOF' 2>/dev/null || echo "No prior content.")
import json, sys
data = json.load(open(sys.argv[1]))
cg = data.get("content_generated", {})
lines = []
for ctype, items in cg.items():
    if items:
        lines.append(f"{ctype}: {len(items)} items generated")
        for item in items[-3:]:
            lines.append(f"  - {item}")
print("\n".join(lines) if lines else "No prior content.")
PYEOF
        fi

        local marketing_prompt="## Pre-Flight (MANDATORY)
Before implementing ANY task:
1. Scan your available skills list and invoke domain-relevant skills
2. Use Context7 MCP (resolve-library-id → query-docs) for any library APIs
3. For unfamiliar domains, use WebSearch to research best practices first

You are a content marketing agent running iteration $content_iteration.
Project root: $PROJECT_DIR

## Content Already Generated
$content_history

## Your Task This Iteration
1. Analyze the product (read README, landing page, existing content)
2. Identify the highest-value content gap (blog post, social content, or pSEO page)
3. Research what performs well in this niche (use WebSearch)
4. Generate ONE piece of high-quality content:
   - Blog post: write to content/blog/ or posts/ directory (1500-2500 words, SEO-optimized)
   - Social media: write to content/social/ (Twitter thread OR LinkedIn post)
   - pSEO page: write to app/pages/ or pages/ (programmatic SEO targeting a long-tail keyword)
5. Commit the new content
6. Update .autopilot/learning.json — append to content_generated.<type> array with title/path/date
7. If applicable, deploy updates to Vercel

## Content Standards
- Every piece must target a specific keyword or audience segment
- Blog posts: include H2/H3 headings, meta description, call-to-action
- Social posts: include hashtags, emojis where appropriate, hook in first line
- pSEO pages: include structured data markup (JSON-LD), unique value per page

Output: AUTOPILOT_STATUS: ITERATION_COMPLETE"

        local mkt_log="$AUTOPILOT_DIR/iterations/marketing-${content_iteration}.log"
        local mkt_exit=0
        timeout "$PHASE_TIMEOUT" claude -p "$marketing_prompt" \
            --dangerously-skip-permissions --verbose --allowedTools '*' \
            2>&1 | tee "$mkt_log" || mkt_exit=$?

        if [[ $mkt_exit -eq 124 ]]; then
            log_warn "TIMEOUT: Marketing iteration $content_iteration exceeded ${PHASE_TIMEOUT}s"
        fi

        track_iteration_cost "$mkt_log"

        if grep -q "AUTOPILOT_STATUS: MISSION_COMPLETE" "$mkt_log" 2>/dev/null; then
            log_success "Marketing mission complete!"
            sed -i 's/"status"[[:space:]]*:[[:space:]]*"active"/"status": "complete"/' "$AUTOPILOT_DIR/mission.json"
            break
        fi

        aggregate_patterns
        generate_handoff_from_learning

        sleep 3
    done

    local total_items=0
    if [[ -f "$AUTOPILOT_DIR/learning.json" ]]; then
        total_items=$(python3 - "$AUTOPILOT_DIR/learning.json" << 'PYEOF' 2>/dev/null || echo "0")
import json, sys
data = json.load(open(sys.argv[1]))
cg = data.get("content_generated", {})
print(sum(len(v) for v in cg.values() if isinstance(v, list)))
PYEOF
    fi
    log_success "Marketing session ended — $total_items content pieces generated across $content_iteration iterations"
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
    [[ -n "$BUDGET_LIMIT" ]] && log_info "Budget limit: \$$BUDGET_LIMIT"
    log_info "Phase timeout: ${PHASE_TIMEOUT}s"

    # Initialize learning system (no-op if already exists)
    learning_init

    # Initialize cost tracking
    cost_init

    # Resume from previous state
    if [[ "$RESUME" == true ]]; then
        ITERATION=$(get_iteration)
        log_info "Resuming from iteration $ITERATION"
    fi

    # Route to the correct loop based on mode
    local mode
    mode=$(get_mode)

    if [[ "$mode" == "evolve" ]]; then
        # Evolve Mode — autonomous milestone generation + GSD execution
        log_info "Max milestones: $([ $MAX_MILESTONES -gt 0 ] && echo $MAX_MILESTONES || echo "unlimited")"
        [[ -n "$EVOLVE_FOCUS" ]] && log_info "Focus areas: $EVOLVE_FOCUS"
        evolve_main_loop
    elif [[ "$mode" == "execute" ]]; then
        # GSD Execute Mode — uses actual GSD agents and commands
        gsd_main_loop
    elif [[ "$mode" == "build-saas" ]]; then
        # Build-SaaS Mode — fully autonomous SaaS product builder
        local saas_desc
        saas_desc=$(get_mission)
        build_saas_main_loop "$saas_desc"
    elif [[ "$mode" == "marketing" ]]; then
        # Marketing Mode — iterative content generation loop
        marketing_main_loop
    else
        # Mission/Improve/Research — autopilot's own task loop
        while ! should_stop; do
            # Check budget before starting new iteration
            check_budget || break

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

    # Print cost summary if costs.json exists
    if [[ -f "$AUTOPILOT_DIR/costs.json" ]]; then
        local total_cost
        total_cost=$(python3 -c "import json; d=json.load(open('$AUTOPILOT_DIR/costs.json')); print(f\"\${d.get('estimated_cost_usd',0):.4f}\")" 2>/dev/null || echo "?")
        log_info "Estimated cost: \$$total_cost"
    fi

    # Clean up
    rm -f "$AUTOPILOT_DIR/STOP"
    rm -f "$AUTOPILOT_DIR/loop.pid"
}

main "$@"
