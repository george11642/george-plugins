#!/bin/bash
# patch-chrome-plugin-configs.sh
# Ensures Chrome-related plugin configs use the WSL auto-detection wrappers
# instead of hardcoded IPs. Run after plugin updates or as a SessionStart hook.
#
# Patches:
#   1. superpowers-chrome plugin.json -> uses superpowers-chrome-mcp-wrapper.sh
#   2. Playwright external_plugins .mcp.json -> uses playwright-mcp-wrapper.sh

SCRIPTS_DIR="/home/george/.claude/scripts"
SUPERPOWERS_PLUGIN="/home/george/.claude/plugins/cache/superpowers-marketplace/superpowers-chrome"
PLAYWRIGHT_EXTERNAL="/home/george/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/playwright/.mcp.json"

patched=0

# --- Patch superpowers-chrome plugin.json ---
# Find the latest version directory
if [ -d "$SUPERPOWERS_PLUGIN" ]; then
    PLUGIN_JSON=$(find "$SUPERPOWERS_PLUGIN" -name "plugin.json" -path "*/.claude-plugin/*" 2>/dev/null | head -1)
    if [ -n "$PLUGIN_JSON" ] && [ -f "$PLUGIN_JSON" ]; then
        if grep -q '"command": "node"' "$PLUGIN_JSON" 2>/dev/null; then
            # Replace node command with wrapper, clear hardcoded env vars
            sed -i \
                -e 's|"command": "node"|"command": "'"${SCRIPTS_DIR}/superpowers-chrome-mcp-wrapper.sh"'"|' \
                -e 's|"CHROME_WS_HOST": "[^"]*",\?||g' \
                -e 's|"CHROME_WS_PORT": "[^"]*",\?||g' \
                "$PLUGIN_JSON"
            # Clean up empty whitespace lines inside env block
            sed -i '/"env": {/{n;/^[[:space:]]*$/d;}' "$PLUGIN_JSON"
            patched=$((patched + 1))
        fi
    fi
fi

# --- Patch Playwright .mcp.json ---
if [ -f "$PLAYWRIGHT_EXTERNAL" ]; then
    if grep -q '"command": "npx"' "$PLAYWRIGHT_EXTERNAL" 2>/dev/null; then
        cat > "$PLAYWRIGHT_EXTERNAL" << 'PEOF'
{
  "playwright": {
    "command": "/home/george/.claude/scripts/playwright-mcp-wrapper.sh",
    "args": []
  }
}
PEOF
        patched=$((patched + 1))
    fi
fi

if [ "$patched" -gt 0 ]; then
    echo "Patched $patched Chrome plugin config(s) for WSL auto-detection"
fi
