#!/bin/bash
# Framework selector hook (SessionStart)
# Announces current mode and provides framework menu context

MODE_FILE="$HOME/.claude/mode"
CURRENT_MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "autonomous")
CURRENT_DATE=$(date +%Y-%m-%d)

CONTEXT="Active mode: ${CURRENT_MODE}
Date: ${CURRENT_DATE}

Framework Selector - Available Modes:
1. autonomous - Ship fast, minimal gates, delegate everything
2. superpowers - Guided design -> TDD -> execution workflow
3. gsd - ROADMAP.md-driven milestone execution
4. research - Deep analysis only, no file modifications

Switch modes: say 'switch to <mode>' or use /mode-<name> slash commands.
If user opens with a greeting, present this menu. If user jumps into a task, work in current mode."

jq -n --arg ctx "$CONTEXT" '{additionalContext: $ctx}'
