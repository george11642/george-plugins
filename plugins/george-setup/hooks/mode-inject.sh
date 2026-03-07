#!/bin/bash
# Mode injection hook (UserPromptSubmit)
# Reads current mode, detects mode switch keywords, injects mode rules

MODE_FILE="$HOME/.claude/mode"
MODES_DIR="$HOME/.claude/modes"

# Read current mode
CURRENT_MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "autonomous")

# Read user prompt from stdin
INPUT=$(cat)
USER_PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

# Detect mode switch keywords (case-insensitive)
NEW_MODE=""
LOWER_PROMPT=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

if echo "$LOWER_PROMPT" | grep -qE '(switch to autonomous|autonomous mode)'; then
  NEW_MODE="autonomous"
elif echo "$LOWER_PROMPT" | grep -qE '(switch to superpowers|superpowers mode)'; then
  NEW_MODE="superpowers"
elif echo "$LOWER_PROMPT" | grep -qE '(switch to gsd|gsd mode|get stuff done mode)'; then
  NEW_MODE="gsd"
elif echo "$LOWER_PROMPT" | grep -qE '(switch to research|research mode)'; then
  NEW_MODE="research"
fi

# If mode switch detected, update mode file
if [ -n "$NEW_MODE" ]; then
  echo "$NEW_MODE" > "$MODE_FILE"
  CURRENT_MODE="$NEW_MODE"
fi

# Load mode rules from file
MODE_RULES_FILE="$MODES_DIR/${CURRENT_MODE}.txt"
if [ -f "$MODE_RULES_FILE" ]; then
  MODE_RULES=$(cat "$MODE_RULES_FILE")
else
  MODE_RULES="Unknown mode: ${CURRENT_MODE}. Defaulting to autonomous behavior."
fi

# Output JSON with additionalContext
jq -n --arg mode "$CURRENT_MODE" --arg rules "$MODE_RULES" \
  '{additionalContext: ("ACTIVE MODE: " + $mode + "\n\n" + $rules)}'
