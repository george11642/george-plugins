#!/usr/bin/env bash
# Sentry Auto-Fix Scanner
# Spawns a Claude instance with sentry-autofix agent to scan and fix issues
set -euo pipefail

PROJECT_DIR="${1:-.}"
MAX_ISSUES="${2:-10}"
SEVERITY="${3:-high}"
TIMEOUT="${4:-1800}"

RESULTS_FILE="${PROJECT_DIR}/.autopilot/sentry-scan-results.json"
mkdir -p "$(dirname "$RESULTS_FILE")"

PROMPT="You are running as the sentry-autofix agent.
Read the agent definition at ~/.claude/agents/sentry-autofix.md for your full instructions.

Scan Sentry for the top $MAX_ISSUES unresolved issues with severity >= $SEVERITY.
For each issue: analyze, fix if possible, commit the fix.
Write results to $RESULTS_FILE.

Project directory: $PROJECT_DIR
Max issues to process: $MAX_ISSUES
Minimum severity: $SEVERITY

Output: SENTRY_SCAN_COMPLETE when done."

echo "Starting Sentry scan (max $MAX_ISSUES issues, severity >= $SEVERITY)..."
timeout "$TIMEOUT" claude -p "$PROMPT" \
    --dangerously-skip-permissions \
    --verbose \
    --allowedTools '*' \
    2>&1 | tee "${PROJECT_DIR}/.autopilot/sentry-scan.log"

echo "Scan complete. Results at $RESULTS_FILE"
