#!/usr/bin/env bash
#
# ralph-gsd-monitor.sh - Autonomous Monitor for ralph-gsd
#
# Runs ralph-gsd, checks evaluator output, runs Claude fix passes
# if issues are found, then restarts. Exits cleanly when evaluator
# reports CLEAN or after MAX_ATTEMPTS fix cycles.
#
# Usage:
#   bash ralph-gsd-monitor.sh [--project-dir PATH] [--max-attempts N]
#
# Background usage:
#   nohup bash /home/george/.claude/scripts/ralph-gsd-monitor.sh \
#     >> /home/george/projects/active/businessagent/.planning/ralph-gsd-monitor.log 2>&1 &

set -euo pipefail

#=============================================================================
# Configuration
#=============================================================================

PROJECT_DIR="${PROJECT_DIR:-/home/george/projects/active/businessagent}"
RALPH="/home/george/.claude/scripts/ralph-gsd.sh"
CLAUDE_BIN="${CLAUDE_BIN:-$(which claude 2>/dev/null || echo '/home/george/.local/bin/claude')}"
MAX_ATTEMPTS=5
MONITOR_LOG=""  # Set below after PROJECT_DIR is parsed

#=============================================================================
# Argument parsing
#=============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"; shift 2 ;;
    --max-attempts)
      MAX_ATTEMPTS="$2"; shift 2 ;;
    --help|-h)
      sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

PLANNING_DIR="$PROJECT_DIR/.planning"
RALPH_LOG="$PLANNING_DIR/ralph-gsd.log"
MONITOR_LOG="$PLANNING_DIR/ralph-gsd-monitor.log"

#=============================================================================
# Helpers
#=============================================================================

log() {
  local msg="[MONITOR $(date '+%H:%M:%S')] $*"
  echo "$msg" | tee -a "$MONITOR_LOG"
}

get_latest_eval_log() {
  ls -t "$PLANNING_DIR/evaluator-"*.log 2>/dev/null | head -1
}

# Returns 0 (true) if clean, 1 (false) if issues found
evaluator_clean() {
  local eval_log="$1"
  if [[ ! -f "$eval_log" ]]; then
    log "No evaluator log at $eval_log — treating as clean"
    return 0
  fi
  if grep -q "EVALUATOR_STATUS: ISSUES_FOUND" "$eval_log" 2>/dev/null; then
    return 1
  fi
  return 0
}

run_ralph() {
  log "Starting ralph-gsd (attempt $attempt/$MAX_ATTEMPTS)..."
  bash "$RALPH" \
    --project-dir "$PROJECT_DIR" \
    --skip-discuss \
    --max-parallel 4 \
    >> "$RALPH_LOG" 2>&1 || true
  log "ralph-gsd exited (exit code: $?)"
}

run_fix_pass() {
  local eval_log="$1"
  log "Running Claude fix pass for evaluator log: $eval_log"

  if [[ ! -x "$CLAUDE_BIN" ]]; then
    log "ERROR: claude binary not found or not executable at: $CLAUDE_BIN"
    return 1
  fi

  local findings
  findings=$(cat "$eval_log")

  local fix_prompt
  fix_prompt="You are a fix agent for ClientOS at $PROJECT_DIR.
The evaluator found issues. Fix ALL of them, then verify the project is clean.

EVALUATOR FINDINGS:
$findings

RULES:
- Read each affected file before editing
- Make minimal correct fixes only
- After all fixes run: cd $PROJECT_DIR && pnpm test --run 2>&1 | tail -10
- Also run: cd $PROJECT_DIR && npx tsc --noEmit 2>&1 | tail -10
- Both must show 0 errors before you finish
- Do NOT restart ralph-gsd — just fix and verify
- If a finding is already fixed, skip it

Return: files changed + final test count + type-check result (max 15 lines)"

  "$CLAUDE_BIN" \
    --dangerously-skip-permissions \
    -p "$fix_prompt" \
    2>&1 | tee -a "$MONITOR_LOG"

  log "Fix pass complete"
}

verify_clean() {
  log "Verifying clean state (TypeScript + tests)..."
  cd "$PROJECT_DIR"

  # TypeScript check
  local ts_out
  ts_out=$(npx tsc --noEmit 2>&1 | tail -5) || true
  if echo "$ts_out" | grep -qE "error TS"; then
    log "TypeScript errors remain: $ts_out"
    return 1
  fi
  log "TypeScript: clean"

  # Test suite
  local test_out
  test_out=$(pnpm test --run 2>&1 | tail -5) || true
  log "Tests: $test_out"

  if echo "$test_out" | grep -qE "[1-9][0-9]* failed"; then
    log "Test failures remain"
    return 1
  fi

  log "CLEAN — TypeScript and tests pass"
  return 0
}

#=============================================================================
# Setup
#=============================================================================

mkdir -p "$PLANNING_DIR"
log "========================================================"
log "ralph-gsd-monitor starting"
log "  Project : $PROJECT_DIR"
log "  Ralph   : $RALPH"
log "  Claude  : $CLAUDE_BIN"
log "  Max     : $MAX_ATTEMPTS fix attempts"
log "========================================================"

if [[ ! -f "$RALPH" ]]; then
  log "ERROR: ralph-gsd.sh not found at $RALPH"
  exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  log "ERROR: project dir not found: $PROJECT_DIR"
  exit 1
fi

#=============================================================================
# Main loop
#=============================================================================

attempt=0

while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
  attempt=$((attempt + 1))

  run_ralph

  eval_log=$(get_latest_eval_log)

  if [[ -z "$eval_log" ]]; then
    log "No evaluator log found after ralph-gsd run — assuming clean exit"
    log "SUCCESS — ralph-gsd completed without evaluator issues"
    exit 0
  fi

  log "Latest evaluator log: $eval_log"

  if evaluator_clean "$eval_log"; then
    log "SUCCESS — evaluator reports CLEAN. All done!"
    exit 0
  fi

  log "WARNING — evaluator found issues (fix attempt $attempt/$MAX_ATTEMPTS)"

  # Fix pass is BLOCKING — wait for claude to finish before restarting
  run_fix_pass "$eval_log"

  # Verify before restarting ralph
  if verify_clean; then
    log "Fix pass succeeded — sleeping 3s then restarting ralph-gsd..."
    sleep 3
  else
    log "Fix pass incomplete — sleeping 5s then retrying..."
    sleep 5
  fi
done

log "FAILED — max fix attempts ($MAX_ATTEMPTS) reached — manual review needed"
log "Last evaluator log: $(get_latest_eval_log)"
exit 1
