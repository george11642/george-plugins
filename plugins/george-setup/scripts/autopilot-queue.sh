#!/usr/bin/env bash
set -euo pipefail

QUEUE_FILE="$HOME/.claude/autopilot/queue.json"
MISSION_FILE="$HOME/.claude/autopilot/mission.json"
AUDIT_FILE="$HOME/.claude/autopilot/audit.jsonl"
STOP_FILE="$HOME/.claude/autopilot/STOP"

usage() {
  cat <<'HELP'
autopilot-queue.sh — Manage the autopilot task queue

Commands:
  add       Add a task to the queue
  list      List queue items
  remove    Remove a task by ID
  status    Show supervisor status
  stop      Create STOP file (pause supervisor)
  resume    Remove STOP file (unpause supervisor)
  clean     Archive completed items older than 7 days
  audit     Show recent audit log entries

Run any command with --help for details.
HELP
}

ensure_queue() {
  mkdir -p "$(dirname "$QUEUE_FILE")"
  [[ -f "$QUEUE_FILE" ]] || echo '{"items":[]}' > "$QUEUE_FILE"
}

atomic_write() {
  local tmp="${QUEUE_FILE}.tmp.$$"
  cat > "$tmp"
  mv "$tmp" "$QUEUE_FILE"
}

cmd_add() {
  local prompt="" project="$PWD" priority=5 budget="" scheduled_after="null" depends_on="null" recurring=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt)      prompt="$2"; shift 2 ;;
      --project)     project="$2"; shift 2 ;;
      --priority)    priority="$2"; shift 2 ;;
      --budget)      budget="$2"; shift 2 ;;
      --scheduled-after) scheduled_after="\"$2\""; shift 2 ;;
      --depends-on)  depends_on="\"$2\""; shift 2 ;;
      --recurring)   recurring="$2"; shift 2 ;;
      --help) echo "Usage: $0 add --prompt TEXT [--project DIR] [--priority N] [--budget USD] [--scheduled-after ISO] [--depends-on ID] [--recurring SECONDS]"; return 0 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done
  [[ -z "$prompt" ]] && { echo "Error: --prompt is required" >&2; return 1; }

  if [[ -z "$budget" ]]; then
    budget=$(jq -r '.budget.per_task_max_usd' "$MISSION_FILE" 2>/dev/null || echo "2.00")
  fi

  local task_id="task-$(date +%s)-$(head -c4 /dev/urandom | xxd -p)"
  local task_type="task"
  local recurrence="null"
  if [[ "$recurring" -gt 0 ]]; then
    task_type="recurring"
    recurrence="$recurring"
  fi

  ensure_queue
  jq --arg id "$task_id" \
     --arg type "$task_type" \
     --argjson pri "$priority" \
     --arg prompt "$prompt" \
     --arg project "$project" \
     --argjson budget "$budget" \
     --argjson scheduled "$scheduled_after" \
     --argjson depends "$depends_on" \
     --argjson recurrence "$recurrence" \
     --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.items += [{
      id: $id, type: $type, priority: $pri, status: "pending",
      prompt: $prompt, project_dir: $project, max_budget_usd: $budget,
      scheduled_after: $scheduled, depends_on: $depends,
      recurrence_interval_seconds: $recurrence,
      created_at: $now, started_at: null, completed_at: null,
      result: null, session_id: null, error: null
    }]' "$QUEUE_FILE" | atomic_write

  echo "Added: $task_id"
}

cmd_list() {
  local filter="pending running" show_all=false status_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)    show_all=true; shift ;;
      --status) status_filter="$2"; shift 2 ;;
      --help)   echo "Usage: $0 list [--status STATUS] [--all]"; return 0 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  ensure_queue
  local jq_filter
  if [[ -n "$status_filter" ]]; then
    jq_filter="select(.status == \"$status_filter\")"
  elif [[ "$show_all" == true ]]; then
    jq_filter="."
  else
    jq_filter='select(.status == "pending" or .status == "running")'
  fi

  printf "%-36s  %-4s  %-10s  %-20s  %s\n" "ID" "PRI" "STATUS" "SCHEDULED" "PROMPT"
  printf "%-36s  %-4s  %-10s  %-20s  %s\n" "----" "---" "------" "---------" "------"
  jq -r ".items[] | $jq_filter | [.id, (.priority|tostring), .status, (.scheduled_after // \"-\"), .prompt[:60]] | @tsv" "$QUEUE_FILE" |
    while IFS=$'\t' read -r id pri st sched prompt; do
      printf "%-36s  %-4s  %-10s  %-20s  %s\n" "$id" "$pri" "$st" "$sched" "$prompt"
    done
}

cmd_remove() {
  local task_id="${1:-}"
  [[ -z "$task_id" ]] && { echo "Usage: $0 remove <task-id>" >&2; return 1; }
  ensure_queue
  local before after
  before=$(jq '.items | length' "$QUEUE_FILE")
  jq --arg id "$task_id" '.items = [.items[] | select(.id != $id)]' "$QUEUE_FILE" | atomic_write
  after=$(jq '.items | length' "$QUEUE_FILE")
  if [[ "$before" -eq "$after" ]]; then
    echo "No task found with ID: $task_id" >&2; return 1
  fi
  echo "Removed: $task_id"
}

cmd_status() {
  echo "=== Autopilot Status ==="
  local name daily_spent daily_max total_spent total_max
  name=$(jq -r '.name' "$MISSION_FILE" 2>/dev/null || echo "unknown")
  daily_spent=$(jq -r '.budget.spent_today_usd' "$MISSION_FILE" 2>/dev/null || echo "?")
  daily_max=$(jq -r '.budget.daily_max_usd' "$MISSION_FILE" 2>/dev/null || echo "?")
  total_spent=$(jq -r '.budget.spent_total_usd' "$MISSION_FILE" 2>/dev/null || echo "?")
  total_max=$(jq -r '.budget.total_max_usd' "$MISSION_FILE" 2>/dev/null || echo "?")
  echo "Mission:  $name"
  echo "Budget:   \$${daily_spent}/\$${daily_max} daily | \$${total_spent}/\$${total_max} total"

  ensure_queue
  echo ""
  echo "Queue:"
  for s in pending running completed failed deferred; do
    local cnt
    cnt=$(jq "[.items[] | select(.status == \"$s\")] | length" "$QUEUE_FILE")
    printf "  %-12s %d\n" "$s" "$cnt"
  done

  echo ""
  if [[ -f "$STOP_FILE" ]]; then
    echo "STOP file:  ACTIVE (supervisor paused)"
  else
    echo "STOP file:  none"
  fi

  local svc
  svc=$(systemctl --user is-active claude-supervisor.service 2>/dev/null || echo "inactive")
  echo "Supervisor: $svc"
}

cmd_stop() {
  mkdir -p "$(dirname "$STOP_FILE")"
  touch "$STOP_FILE"
  echo "STOP file created — supervisor will pause after current task."
}

cmd_resume() {
  rm -f "$STOP_FILE"
  echo "STOP file removed — supervisor will resume."
}

cmd_clean() {
  ensure_queue
  local archive_dir="$HOME/.claude/autopilot/archive"
  local archive_file="$archive_dir/queue-archive-$(date +%Y%m%d).json"
  mkdir -p "$archive_dir"

  local cutoff
  cutoff=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)

  local count
  count=$(jq --arg cutoff "$cutoff" \
    '[.items[] | select((.status == "completed" or .status == "failed") and .completed_at != null and .completed_at < $cutoff)] | length' \
    "$QUEUE_FILE")

  if [[ "$count" -eq 0 ]]; then
    echo "No items to archive."; return 0
  fi

  # Extract old items into archive
  jq --arg cutoff "$cutoff" \
    '[.items[] | select((.status == "completed" or .status == "failed") and .completed_at != null and .completed_at < $cutoff)]' \
    "$QUEUE_FILE" > "$archive_file"

  # Remove them from queue
  jq --arg cutoff "$cutoff" \
    '.items = [.items[] | select(not((.status == "completed" or .status == "failed") and .completed_at != null and .completed_at < $cutoff))]' \
    "$QUEUE_FILE" | atomic_write

  echo "Archived $count items to $archive_file"
}

cmd_audit() {
  local lines=20
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lines) lines="$2"; shift 2 ;;
      --help)  echo "Usage: $0 audit [--lines N]"; return 0 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done
  [[ -f "$AUDIT_FILE" ]] || { echo "No audit log found."; return 0; }
  tail -n "$lines" "$AUDIT_FILE" | jq .
}

# --- Main ---
cmd="${1:-}"
shift 2>/dev/null || true
case "$cmd" in
  add)    cmd_add "$@" ;;
  list)   cmd_list "$@" ;;
  remove) cmd_remove "$@" ;;
  status) cmd_status ;;
  stop)   cmd_stop ;;
  resume) cmd_resume ;;
  clean)  cmd_clean ;;
  audit)  cmd_audit "$@" ;;
  --help|-h|"") usage ;;
  *) echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
esac
