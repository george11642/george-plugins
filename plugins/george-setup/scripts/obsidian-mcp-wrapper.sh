#!/usr/bin/env bash
# Obsidian MCP wrapper for WSL2
# Resolves Windows host IP and proxies to Obsidian Local REST API

set -euo pipefail

# Resolve Windows host IP from WSL2 (use default gateway, not resolv.conf which Tailscale overrides)
WIN_HOST_IP=$(ip route show default | awk '{print $3; exit}')
OBSIDIAN_PORT="${OBSIDIAN_PORT:-27124}"
OBSIDIAN_URL="https://${WIN_HOST_IP}:${OBSIDIAN_PORT}"

export OBSIDIAN_BASE_URL="${OBSIDIAN_URL}"
export OBSIDIAN_API_KEY="${OBSIDIAN_API_KEY:?OBSIDIAN_API_KEY must be set}"
export OBSIDIAN_VERIFY_SSL="${OBSIDIAN_VERIFY_SSL:-false}"

# Run the Obsidian MCP server
exec npx -y obsidian-mcp-server
