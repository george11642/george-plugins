#!/usr/bin/env bash
set -euo pipefail

# george-plugins setup — bootstrap George's Claude Code marketplace
# Usage: curl -fsSL https://raw.githubusercontent.com/george11642/george-plugins/main/setup.sh | bash

REPO_URL="https://github.com/george11642/george-plugins.git"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/george-plugins"
CLAUDE_DIR="$HOME/.claude"

echo "=== George's Claude Code Setup ==="
echo ""

# Check prerequisites
command -v git >/dev/null 2>&1 || { echo "Error: git is required"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Error: Node.js is required"; exit 1; }

# Create Claude directories
mkdir -p "$CLAUDE_DIR/plugins/marketplaces"
mkdir -p "$CLAUDE_DIR/memory"
mkdir -p "$CLAUDE_DIR/scripts"

# Clone or update the marketplace
if [ -d "$MARKETPLACE_DIR" ]; then
    echo "Marketplace already exists, updating..."
    cd "$MARKETPLACE_DIR"
    git pull --ff-only origin main
else
    echo "Cloning george-plugins marketplace..."
    git clone "$REPO_URL" "$MARKETPLACE_DIR"
fi

# Register the marketplace in Claude's plugin config
PLUGIN_CONFIG="$CLAUDE_DIR/plugins/plugins.json"
if [ -f "$PLUGIN_CONFIG" ]; then
    # Check if already registered
    if grep -q "george-plugins" "$PLUGIN_CONFIG" 2>/dev/null; then
        echo "Marketplace already registered."
    else
        echo "Note: Marketplace cloned. Register it in Claude Code with:"
        echo "  /plugin marketplace add george11642/george-plugins"
    fi
else
    echo "Note: Register the marketplace in Claude Code with:"
    echo "  /plugin marketplace add george11642/george-plugins"
fi

# Copy CLAUDE.md template if user doesn't have one
if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    TEMPLATE="$MARKETPLACE_DIR/plugins/george-setup/templates/CLAUDE.md.template"
    if [ -f "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$CLAUDE_DIR/CLAUDE.md"
        echo "Installed CLAUDE.md template"
    fi
else
    echo "CLAUDE.md already exists (not overwriting)"
fi

# Copy orchestration memory if not present
if [ ! -f "$CLAUDE_DIR/memory/orchestration.md" ]; then
    MEMORY_TEMPLATE="$MARKETPLACE_DIR/plugins/george-setup/templates/orchestration-memory.md"
    if [ -f "$MEMORY_TEMPLATE" ]; then
        cp "$MEMORY_TEMPLATE" "$CLAUDE_DIR/memory/orchestration.md"
        echo "Installed orchestration memory"
    fi
fi

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Next steps:"
echo "  1. Open Claude Code"
echo "  2. Run: /plugin install george-setup@george-plugins"
echo "  3. Run: /george-setup:install    (for full setup with MCP servers)"
echo ""
echo "Or for a minimal setup (just orchestration):"
echo "  /plugin install george-setup@george-plugins"
echo "  /george-setup:install --minimal"
echo ""
echo "See also:"
echo "  /plugin install ralph-gsd@george-plugins      (autonomous milestone execution)"
echo "  /plugin install autopilot@george-plugins       (overnight autonomous coding)"
