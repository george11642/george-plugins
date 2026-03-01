#!/usr/bin/env bash
# PostHog Analytics Analyzer
# Spawns a Claude instance with posthog-analyzer agent
set -euo pipefail

PROJECT_DIR="${1:-.}"
TIMEOUT="${2:-1200}"

RESULTS_FILE="${PROJECT_DIR}/.autopilot/posthog-analysis.json"
mkdir -p "$(dirname "$RESULTS_FILE")"

PROMPT="You are running as the posthog-analyzer agent.
Read the agent definition at ~/.claude/agents/posthog-analyzer.md for your full instructions.

Analyze PostHog metrics for this project.
Write analysis to $RESULTS_FILE and a human-readable summary to ${PROJECT_DIR}/.autopilot/posthog-analysis.md.

Project directory: $PROJECT_DIR

Output: POSTHOG_ANALYSIS_COMPLETE when done."

echo "Starting PostHog analysis..."
timeout "$TIMEOUT" claude -p "$PROMPT" \
    --dangerously-skip-permissions \
    --verbose \
    --allowedTools '*' \
    2>&1 | tee "${PROJECT_DIR}/.autopilot/posthog-analyze.log"

echo "Analysis complete. Results at $RESULTS_FILE"
