#!/usr/bin/env bash
# george-setup install script
# Bootstraps Claude config on a new machine.
# Run: bash ~/.claude/plugins/marketplaces/george-plugins/plugins/george-setup/scripts/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$HOME/.claude"

echo "=== george-setup install ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Claude dir: $CLAUDE_DIR"
echo ""

# 1. CLAUDE.md global instructions
if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  cp "$PLUGIN_DIR/templates/global-claude-md.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "OK Installed CLAUDE.md"
else
  echo "-- CLAUDE.md already exists, skipping (delete to reinstall)"
fi

# 2. Hooks
mkdir -p "$CLAUDE_DIR/hooks"
for hook in memory-reminder.js statusline.js; do
  src="$PLUGIN_DIR/hooks/$hook"
  if [ -f "$src" ]; then
    cp "$src" "$CLAUDE_DIR/hooks/$hook"
    echo "OK Installed hook: $hook"
  else
    echo "!! Hook not found in repo: $hook"
  fi
done

# Also install gsd-statusline.js as the expected name in settings.json
if [ -f "$CLAUDE_DIR/hooks/statusline.js" ]; then
  cp "$CLAUDE_DIR/hooks/statusline.js" "$CLAUDE_DIR/hooks/gsd-statusline.js"
  echo "OK Copied statusline.js -> gsd-statusline.js"
fi

# 3. Memory files
mkdir -p "$CLAUDE_DIR/memory"
if [ ! -f "$CLAUDE_DIR/memory/orchestration.md" ]; then
  if [ -f "$PLUGIN_DIR/templates/orchestration.md" ]; then
    cp "$PLUGIN_DIR/templates/orchestration.md" "$CLAUDE_DIR/memory/orchestration.md"
    echo "OK Installed memory/orchestration.md"
  else
    echo "!! orchestration.md template not found"
  fi
else
  echo "-- memory/orchestration.md already exists, skipping"
fi

# 4. Scripts — symlink into ~/.claude/scripts/
mkdir -p "$CLAUDE_DIR/scripts"
SCRIPTS=(
  chrome-devtools-mcp-wrapper.sh
  ios-sim-health.sh
  ios-sim-start.sh
  ios-sim-stop.sh
  vnc_capture.py
  vnc_interact.py
)
for script in "${SCRIPTS[@]}"; do
  src="$PLUGIN_DIR/scripts/$script"
  dst="$CLAUDE_DIR/scripts/$script"
  if [ -f "$src" ]; then
    # Make executable
    chmod +x "$src" 2>/dev/null || true
    ln -sf "$src" "$dst"
    echo "OK Symlinked script: $script"
  else
    echo "!! Script not found in repo (skipping): $script"
  fi
done

# 5. Create required directories
mkdir -p "$CLAUDE_DIR/autopilot-knowledge"
echo "OK Created autopilot-knowledge dir"

mkdir -p "$CLAUDE_DIR/memory"
echo "OK memory dir exists"

echo ""
echo "=== Manual steps still needed ==="
echo ""
echo "1. Copy and configure settings.json:"
echo "   cp $PLUGIN_DIR/templates/settings-template.json $CLAUDE_DIR/settings.json"
echo "   Then edit and fill in YOUR_*_HERE placeholders"
echo ""
echo "2. Copy and configure MCP config:"
echo "   cp $PLUGIN_DIR/templates/mcp-template.json $CLAUDE_DIR/.mcp.json"
echo "   Then edit and fill in YOUR_*_HERE API keys"
echo ""
echo "3. Register plugin marketplaces (see SETUP.md)"
echo ""
echo "4. Enable plugins in Claude Code (see SETUP.md)"
echo ""
echo "5. Get API keys:"
echo "   - Gemini: https://aistudio.google.com/app/apikey"
echo "   - GitHub: run 'gh auth login'"
echo ""
echo "6. Build any MCP servers that need it (npm install && npm run build)"
echo ""
echo "7. See $PLUGIN_DIR/SETUP.md for full instructions"
echo ""
echo "=== Install complete ==="
