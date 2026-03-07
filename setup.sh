#!/usr/bin/env bash
# George's Claude Code Setup - One-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/george11642/george-plugins/main/setup.sh | bash
set -euo pipefail

GITHUB_USER="george11642"
REPO_NAME="george-plugins"
MARKETPLACE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/marketplaces"
PLUGIN_DIR="$MARKETPLACE_DIR/$GITHUB_USER-$REPO_NAME"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

echo "=== George's Claude Code Setup ==="
echo ""

# Check prerequisites
if ! command -v git &>/dev/null; then
  echo "ERROR: git is required. Install it first."
  exit 1
fi

if ! command -v node &>/dev/null; then
  echo "WARNING: Node.js not found. Some hooks/MCP servers require Node.js 20+."
fi

# Create dirs
mkdir -p "$MARKETPLACE_DIR"
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/modes"
mkdir -p "$CLAUDE_DIR/skills"

# Clone or update marketplace
if [ -d "$PLUGIN_DIR/.git" ]; then
  echo "Updating existing marketplace..."
  git -C "$PLUGIN_DIR" pull --quiet
else
  echo "Cloning marketplace..."
  git clone --quiet "https://github.com/$GITHUB_USER/$REPO_NAME.git" "$PLUGIN_DIR"
fi
echo "  ✓ Marketplace ready at $PLUGIN_DIR"

# Run install script
echo ""
bash "$PLUGIN_DIR/plugins/george-setup/scripts/install.sh"

echo ""
echo "=== Next Steps ==="
echo "1. Open Claude Code and run: /plugin marketplace add george11642/george-plugins"
echo "2. Run: /plugin install george-setup@george-plugins"
echo "3. Run: /george-setup:install"
echo ""
echo "Recommended additional marketplaces:"
echo "  /plugin marketplace add obra/superpowers-marketplace"
echo "  /plugin marketplace add anthropics/claude-plugins-official"
