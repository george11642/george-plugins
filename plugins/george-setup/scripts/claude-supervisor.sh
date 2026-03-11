#!/usr/bin/env bash
# claude-supervisor.sh — Durable loop that processes autopilot task queue
# Reads queue.json, invokes claude -p for each ready task, tracks budget
set -euo pipefail

AUTOPILOT_DIR="$HOME/.claude/autopilot"
QUEUE="$AUTOPILOT_DIR/queue.json"
MISSION="$AUTOPILOT_DIR/mission.json"
AUDIT="$AUTOPILOT_DIR/audit.jsonl"
STOP_FILE="$AUTOPILOT_DIR/STOP"
STRATEGY="$AUTOPILOT_DIR/strategy.md"
LAST_SESSION="$AUTOPILOT_DIR/last-session.json"

# --- Helpers ---

log() { echo "[$(date -Iseconds)] $*" >&2; }

jq_update() {
  local file="$1" filter="$2"
  local tmp="${file}.tmp.$$"
  jq "$filter" "$file" > "$tmp" && mv "$tmp" "$file"
}

notify() {
  local event="$1" message="$2"
  local webhook
  webhook=$(jq -r '.notification_webhook // empty' "$MISSION")
  [[ -z "$webhook" ]] && return 0
  curl -sf -X POST "$webhook" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg e "$event" --arg m "$message" '{event:$e,message:$m,timestamp:now|todate}')" \
    >/dev/null 2>&1 || true
}

calculate_sleep_until_midnight() {
  local now tomorrow_epoch
  now=$(date +%s)
  tomorrow_epoch=$(date -d "tomorrow 00:00:00" +%s)
  echo $(( tomorrow_epoch - now ))
}

get_next_task() {
  # Returns the index + task JSON of the next ready task, or empty
  local now
  now=$(date -Iseconds)
  jq -r --arg now "$now" '
    .items | to_entries[]
    | select(.value.status == "pending")
    | select(.value.scheduled_after == null or .value.scheduled_after <= $now)
    | select(.value.depends_on == null or
        (.value.depends_on | all(. as $dep |
          input_filename | . as $f | null |
          false  # handled below
        )))
    | .key' "$QUEUE" 2>/dev/null | head -1
}

# Dependency check: all depends_on IDs must be "completed" in queue
task_deps_met() {
  local task_json="$1"
  local deps
  deps=$(echo "$task_json" | jq -r '.depends_on // empty')
  [[ -z "$deps" || "$deps" == "null" ]] && return 0
  local all_met
  all_met=$(jq -r --argjson deps "$deps" '
    ($deps | map(. as $d | any(input.items[]; .id == $d and .status == "completed")) | all)
  ' "$QUEUE" 2>/dev/null)
  # Simpler: check each dep
  for dep_id in $(echo "$task_json" | jq -r '.depends_on[]? // empty'); do
    local dep_status
    dep_status=$(jq -r --arg id "$dep_id" '.items[] | select(.id == $id) | .status' "$QUEUE")
    [[ "$dep_status" != "completed" ]] && return 1
  done
  return 0
}

find_next_task_index() {
  local now
  now=$(date -Iseconds)
  # Get pending tasks sorted by priority then created_at
  local candidates
  candidates=$(jq -r --arg now "$now" '
    [.items | to_entries[]
     | select(.value.status == "pending")
     | select(.value.scheduled_after == null or .value.scheduled_after <= $now)]
    | sort_by(.value.priority, .value.created_at)
    | .[].key' "$QUEUE" 2>/dev/null)

  for idx in $candidates; do
    local task_json
    task_json=$(jq ".items[$idx]" "$QUEUE")
    if task_deps_met "$task_json"; then
      echo "$idx"
      return 0
    fi
  done
  return 1
}

count_failures() {
  local base_id="$1"
  grep -c "\"task_id\":\"${base_id}\".*\"status\":\"failed\"" "$AUDIT" 2>/dev/null || echo 0
}

# --- Graceful shutdown ---
RUNNING_TASK_IDX=""
cleanup() {
  log "Caught signal, shutting down..."
  if [[ -n "$RUNNING_TASK_IDX" ]]; then
    log "Resetting task at index $RUNNING_TASK_IDX to pending"
    jq_update "$QUEUE" ".items[$RUNNING_TASK_IDX].status = \"pending\" | .items[$RUNNING_TASK_IDX].started_at = null"
  fi
  exit 0
}
trap cleanup SIGTERM SIGINT

# --- Main Loop ---
log "Supervisor started (pid $$)"

while true; do
  # 1. Check STOP file
  if [[ -f "$STOP_FILE" ]]; then
    log "STOP file detected, pausing..."
    sleep 60; continue
  fi

  # 2-3. Load budget, reset daily if needed
  today=$(date +%Y-%m-%d)
  budget_date=$(jq -r '.budget.today_date' "$MISSION")
  if [[ "$today" != "$budget_date" ]]; then
    log "New day, resetting daily budget"
    jq_update "$MISSION" ".budget.spent_today_usd = 0 | .budget.today_date = \"$today\" | .updated_at = \"$(date -Iseconds)\""
  fi

  spent_today=$(jq -r '.budget.spent_today_usd' "$MISSION")
  daily_max=$(jq -r '.budget.daily_max_usd' "$MISSION")
  spent_total=$(jq -r '.budget.spent_total_usd' "$MISSION")
  total_max=$(jq -r '.budget.total_max_usd' "$MISSION")

  # Check total budget
  if (( $(echo "$spent_total >= $total_max" | bc -l) )); then
    log "Total budget exhausted (\$${spent_total}/\$${total_max})"
    notify "budget_exhausted" "Total budget limit reached"
    exit 0
  fi

  # Check daily budget
  if (( $(echo "$spent_today >= $daily_max" | bc -l) )); then
    sleep_secs=$(calculate_sleep_until_midnight)
    log "Daily budget exhausted (\$${spent_today}/\$${daily_max}), sleeping ${sleep_secs}s until midnight"
    notify "daily_budget_exhausted" "Daily budget limit reached, sleeping until midnight"
    sleep "$sleep_secs"; continue
  fi

  # 4. Find next ready task
  idx=$(find_next_task_index) || { sleep 300; continue; }
  task=$(jq ".items[$idx]" "$QUEUE")
  task_id=$(echo "$task" | jq -r '.id')
  task_prompt=$(echo "$task" | jq -r '.prompt')
  task_dir=$(echo "$task" | jq -r '.project_dir // "/home/george"')
  task_budget=$(echo "$task" | jq -r '.max_budget_usd // 1.0')
  base_id=$(echo "$task_id" | sed 's/-[0-9]*$//')

  # Check failure count — defer if 3+ failures
  failures=$(count_failures "$base_id")
  if (( failures >= 3 )); then
    log "Task $task_id deferred after $failures failures"
    jq_update "$QUEUE" ".items[$idx].status = \"deferred\""
    continue
  fi

  # 6. Mark running
  started_at=$(date -Iseconds)
  log "Starting task: $task_id (priority $(echo "$task" | jq -r '.priority'))"
  jq_update "$QUEUE" ".items[$idx].status = \"running\" | .items[$idx].started_at = \"$started_at\""
  RUNNING_TASK_IDX="$idx"

  # 7. Build context and invoke claude
  CONTEXT="You are running as an autonomous headless session.\n"
  [[ -f "$STRATEGY" ]] && CONTEXT+="$(cat "$STRATEGY")\n\n"
  CONTEXT+="## Current Task\n${task_prompt}\n\n"
  [[ -f "$LAST_SESSION" ]] && CONTEXT+="## Last Session Context\n$(cat "$LAST_SESSION")\n"

  set +e
  RESULT=$(cd "$task_dir" && claude -p "$CONTEXT" \
    --output-format json \
    --max-budget-usd "$task_budget" \
    --dangerously-skip-permissions 2>&1)
  exit_code=$?
  set -e

  completed_at=$(date -Iseconds)
  RUNNING_TASK_IDX=""

  # 8. Parse result
  if [[ $exit_code -eq 0 ]]; then
    session_id=$(echo "$RESULT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
    cost_usd=$(echo "$RESULT" | jq -r '.usage.cost_usd // .cost_usd // 0' 2>/dev/null || echo "0")
    result_text=$(echo "$RESULT" | jq -r '.result // .text // "no output"' 2>/dev/null || echo "$RESULT")
    # Try to extract structured JSON from result text
    summary=$(echo "$result_text" | sed -n '/```json/,/```/p' | sed '1d;$d' | jq -r '.summary // empty' 2>/dev/null || \
      echo "$result_text" | head -c 500)
    status="completed"
    log "Task $task_id completed (cost: \$${cost_usd})"
  else
    session_id=""; cost_usd=0; summary="Exit code $exit_code"; status="failed"
    log "Task $task_id failed (exit $exit_code)"
    notify "task_failed" "Task $task_id failed: $summary"
  fi

  # Update task in queue
  jq_update "$QUEUE" "
    .items[$idx].status = \"$status\" |
    .items[$idx].completed_at = \"$completed_at\" |
    .items[$idx].result = $(echo "$summary" | jq -Rs .) |
    .items[$idx].session_id = \"$session_id\""

  # 9. Audit log
  echo "{\"task_id\":\"$task_id\",\"started_at\":\"$started_at\",\"completed_at\":\"$completed_at\",\"status\":\"$status\",\"cost_usd\":$cost_usd,\"session_id\":\"$session_id\",\"summary\":$(echo "$summary" | jq -Rs .)}" >> "$AUDIT"

  # 10. Handle recurrence
  recurrence=$(echo "$task" | jq -r '.recurrence_interval_seconds // empty')
  if [[ -n "$recurrence" && "$status" == "completed" ]]; then
    next_at=$(date -Iseconds -d "+${recurrence} seconds")
    new_id="${base_id}-$(date +%s)"
    log "Scheduling recurring task $new_id for $next_at"
    jq_update "$QUEUE" ".items += [$(echo "$task" | jq "
      .id = \"$new_id\" | .status = \"pending\" |
      .scheduled_after = \"$next_at\" |
      .started_at = null | .completed_at = null |
      .result = null | .session_id = null | .error = null |
      .created_at = \"$completed_at\"")]"
  fi

  # 11. Save last session context for next task
  jq -n --arg id "$task_id" --arg s "$status" --arg sum "$summary" \
    '{last_task_id:$id,status:$s,summary:$sum,completed_at:now|todate}' > "$LAST_SESSION"

  # 12. Update budget
  jq_update "$MISSION" "
    .budget.spent_today_usd += $cost_usd |
    .budget.spent_total_usd += $cost_usd |
    .updated_at = \"$completed_at\""

  # Budget threshold notification (80%)
  new_total=$(jq -r '.budget.spent_total_usd' "$MISSION")
  threshold=$(echo "$total_max * 0.8" | bc -l)
  if (( $(echo "$new_total >= $threshold" | bc -l) )); then
    notify "budget_warning" "80% of total budget used (\$${new_total}/\$${total_max})"
  fi

  # 13. Rate limit between tasks
  sleep 30
done
