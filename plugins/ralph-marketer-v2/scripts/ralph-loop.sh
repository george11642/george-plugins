#!/bin/bash
set -euo pipefail

MAX_ITERATIONS="${1:-20}"
PROJECT_DIR="$(pwd)"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$PROJECT_DIR/.ralph/state.json"
LOCK_FILE="$PROJECT_DIR/.ralph/loop.lock"

# Lock (prevent concurrent runs)
if [ -f "$LOCK_FILE" ] && kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
  echo "ERROR: Ralph loop already running (PID $(cat "$LOCK_FILE"))"
  exit 1
fi
mkdir -p "$PROJECT_DIR/.ralph"
echo $$ > "$LOCK_FILE"
trap "rm -f '$LOCK_FILE'" EXIT

# Init state if not exists
[ -f "$STATE_FILE" ] || echo '{"iteration":0,"status":"running","completed":[]}' > "$STATE_FILE"

for ((i=1; i<=MAX_ITERATIONS; i++)); do
  echo "=== Ralph Iteration $i/$MAX_ITERATIONS ==="
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting iteration $i" >> "$PROJECT_DIR/.ralph/loop.log"

  # Update iteration in state
  jq --argjson i "$i" '.iteration=$i' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

  # Build the full prompt by reading template and injecting state
  PROMPT="$(cat "$PLUGIN_DIR/scripts/ralph-iteration.md")"
  PRD="$(cat "$PROJECT_DIR/scripts/ralph/prd.json" 2>/dev/null || echo '{}')"
  PROGRESS="$(tail -50 "$PROJECT_DIR/scripts/ralph/progress.txt" 2>/dev/null || echo 'No progress yet')"
  CONFIG="$(cat "$PROJECT_DIR/.ralph/config.json" 2>/dev/null || echo '{}')"

  FULL_PROMPT="$PROMPT
---STATE---
Iteration: $i of $MAX_ITERATIONS
$(cat "$STATE_FILE")
---CONFIG---
$CONFIG
---PRD---
$PRD
---PROGRESS---
$PROGRESS
---END---"

  # Fresh Claude instance - headless, autonomous
  OUTPUT=$(claude --no-interactive --print --dangerously-skip-permissions \
    -p "$FULL_PROMPT" 2>&1) || true

  echo "$OUTPUT" >> "$PROJECT_DIR/.ralph/loop.log"

  # Check if Ralph signals completion
  if echo "$OUTPUT" | grep -q "RALPH_COMPLETE"; then
    jq '.status="completed"' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    echo "=== ALL TASKS COMPLETE ($i iterations) ==="
    echo "$(date '+%Y-%m-%d %H:%M:%S') - COMPLETED after $i iterations" >> "$PROJECT_DIR/.ralph/loop.log"
    exit 0
  fi

  # Check for errors
  if echo "$OUTPUT" | grep -q "RALPH_ERROR"; then
    jq '.status="error"' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    echo "=== ERROR in iteration $i ==="
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR in iteration $i" >> "$PROJECT_DIR/.ralph/loop.log"
    exit 1
  fi

  sleep 2
done

echo "=== MAX ITERATIONS REACHED ($MAX_ITERATIONS) ==="
jq '.status="max_iterations"' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
