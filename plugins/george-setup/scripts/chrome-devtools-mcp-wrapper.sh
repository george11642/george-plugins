#!/bin/bash
# Wrapper for chrome-devtools-mcp that connects to Perplexity Comet on WSL2.
#
# Comet shortcuts are configured with --remote-debugging-port=9222.
# WSL2 NAT mode with localhostForwarding=true allows WSL to reach
# Windows localhost ports directly.
#
# Port discovery priority:
#   1. Known port 9222 (all Comet shortcuts configured with --remote-debugging-port=9222)
#   2. DevToolsActivePort file (fallback for dynamic port)
#   3. Manual override via ~/.claude/comet-cdp.json

set -euo pipefail

# Resolve the correct Chrome host (WSL2 → Windows gateway IP, native → 127.0.0.1)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/resolve-wsl-chrome-host.sh"

COMET_DTP="/mnt/c/Users/george/AppData/Local/Perplexity/Comet/User Data/DevToolsActivePort"
CDP_CONFIG="$HOME/.claude/comet-cdp.json"
CDP_HOST="${CHROME_HOST}"
KNOWN_PORT="${CHROME_PORT}"
CDP_PORT=""

# Helper: check if a port is reachable (quick check)
port_ok() {
  curl -s --connect-timeout 2 "http://${CDP_HOST}:${1}/json/version" >/dev/null 2>&1
}

# 1. Try the known configured port first (shortcuts use 9222)
if port_ok "$KNOWN_PORT"; then
  CDP_PORT="$KNOWN_PORT"
fi

# 2. Try DevToolsActivePort (first line = port)
if [[ -z "$CDP_PORT" && -f "$COMET_DTP" ]]; then
  DTP_PORT="$(head -n1 "$COMET_DTP" 2>/dev/null | tr -d '[:space:]')"
  if [[ -n "$DTP_PORT" ]] && port_ok "$DTP_PORT"; then
    CDP_PORT="$DTP_PORT"
  fi
fi

# 3. Fallback: manual config file
if [[ -z "$CDP_PORT" && -f "$CDP_CONFIG" ]]; then
  CFG_PORT="$(grep -o '"port"\s*:\s*[0-9]*' "$CDP_CONFIG" 2>/dev/null | grep -o '[0-9]*')"
  if [[ -n "$CFG_PORT" ]] && port_ok "$CFG_PORT"; then
    CDP_PORT="$CFG_PORT"
  fi
fi

# 4. Last resort — use known port even if it didn't respond (Comet may not be up yet)
if [[ -z "$CDP_PORT" ]]; then
  CDP_PORT="$KNOWN_PORT"
fi

# Get the exact WebSocket debugger URL from the running browser and replace the
# host with the resolved one (in case Chrome reports 127.0.0.1 but WSL needs the gateway IP).
RAW_WS=$(curl -s --connect-timeout 3 "http://${CDP_HOST}:${CDP_PORT}/json/version" \
  | grep -o '"webSocketDebuggerUrl":"[^"]*"' \
  | cut -d'"' -f4)

if [[ -n "$RAW_WS" ]]; then
  # Substitute whatever host Chrome reported with the resolved host
  WS_URL=$(echo "$RAW_WS" | sed "s|ws://[^:/]*:|ws://${CDP_HOST}:|")
  exec npx -y chrome-devtools-mcp@latest --wsEndpoint="$WS_URL"
else
  exec npx -y chrome-devtools-mcp@latest --browserUrl="http://${CDP_HOST}:${CDP_PORT}"
fi
