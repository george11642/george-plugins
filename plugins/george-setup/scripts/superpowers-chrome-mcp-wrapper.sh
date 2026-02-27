#!/bin/bash
# Wrapper for superpowers-chrome MCP that auto-resolves the Chrome host on WSL2.
# Sets CHROME_WS_HOST and CHROME_WS_PORT env vars before launching the Node server.
# The real server path is passed as the first argument (from plugin.json args).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/resolve-wsl-chrome-host.sh"

export CHROME_WS_HOST="${CHROME_HOST}"
export CHROME_WS_PORT="${CHROME_PORT}"

exec node "$@"
