#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

echo "=== George's Claude Code Setup Installer ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Claude dir: $CLAUDE_DIR"
echo ""

# Create all necessary directories
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/modes"
mkdir -p "$CLAUDE_DIR/skills"

# 1. Install CLAUDE.md (only if not already present, to avoid overwriting customizations)
if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo "Installing CLAUDE.md..."
  cp "$PLUGIN_DIR/templates/global-claude-md.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  ✓ CLAUDE.md installed"
else
  echo "  ⚠ CLAUDE.md already exists, skipping (backup to CLAUDE.md.bak first if you want to update)"
  echo "    To update: cp $PLUGIN_DIR/templates/global-claude-md.md $CLAUDE_DIR/CLAUDE.md"
fi

# 2. Install hooks
echo ""
echo "Installing hooks..."
for hook in "$PLUGIN_DIR/hooks/"*; do
  hook_name="$(basename "$hook")"
  cp "$hook" "$CLAUDE_DIR/hooks/$hook_name"
  chmod +x "$CLAUDE_DIR/hooks/$hook_name"
  echo "  ✓ $hook_name"
done

# 3. Install modes
echo ""
echo "Installing modes..."
for mode in "$PLUGIN_DIR/modes/"*.txt; do
  mode_name="$(basename "$mode")"
  cp "$mode" "$CLAUDE_DIR/modes/$mode_name"
  echo "  ✓ $mode_name"
done

# 4. Install skills
echo ""
echo "Installing 16 master skills..."
for skill_dir in "$PLUGIN_DIR/skills/"*/; do
  skill_name="$(basename "$skill_dir")"
  if [ "$skill_name" = "_archive" ]; then continue; fi

  dest="$CLAUDE_DIR/skills/$skill_name"
  if [ -d "$dest" ]; then
    echo "  ↺ Updating $skill_name"
  else
    echo "  ✓ Installing $skill_name"
  fi
  mkdir -p "$dest"
  cp -r "$skill_dir"* "$dest/" 2>/dev/null || true
done

# 5. Set default mode to autonomous
echo ""
echo "Setting default mode..."
echo "autonomous" > "$CLAUDE_DIR/mode"
echo "  ✓ Default mode: autonomous"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Configure hooks in ~/.claude/settings.json:"
echo '   "hooks": {'
echo '     "SessionStart": ["~/.claude/hooks/framework-selector.sh", "~/.claude/hooks/gsd-check-update.js"],'
echo '     "UserPromptSubmit": ["~/.claude/hooks/mode-inject.sh"],'
echo '     "PostToolUse": ["~/.claude/hooks/gsd-context-monitor.js"],'
echo '     "Stop": ["~/.claude/hooks/memory-reminder.js"]'
echo '   },'
echo '   "statusLine": "~/.claude/hooks/gsd-statusline.js"'
echo ""
echo "2. Install recommended marketplaces:"
echo "   /plugin marketplace add obra/superpowers-marketplace"
echo "   /plugin marketplace add anthropics/claude-plugins-official"
echo ""
echo "3. Install MCP servers (optional, for Gemini/LaTeX/iOS):"
echo "   See plugins/george-setup/mcp-servers/ for instructions"
