#!/bin/bash
# resolve-wsl-chrome-host.sh
# Auto-detects WSL2 and resolves the Windows host IP for Chrome DevTools Protocol.
#
# Usage:
#   source resolve-wsl-chrome-host.sh   # sets CHROME_HOST and CHROME_PORT
#   OR
#   ./resolve-wsl-chrome-host.sh         # prints HOST:PORT to stdout
#
# On WSL2: resolves the Windows host IP via the default gateway
# On native: uses 127.0.0.1
#
# Override defaults with env vars:
#   CHROME_CDP_PORT=9222  (default)
#   CHROME_CDP_HOST=...   (overrides auto-detection)

_resolve_chrome_host() {
    local host="${CHROME_CDP_HOST:-}"
    local port="${CHROME_CDP_PORT:-9222}"

    if [ -z "$host" ]; then
        # Check if running inside WSL2
        if grep -qi microsoft /proc/version 2>/dev/null || [ -n "$WSL_DISTRO_NAME" ]; then
            # WSL2: try localhost first (works with mirrored networking / localhostForwarding)
            if curl -s --connect-timeout 1 "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1; then
                host="127.0.0.1"
            else
                # Fallback: Windows host via default gateway IP
                host=$(ip route show default 2>/dev/null | awk '{print $3}')
                if [ -z "$host" ]; then
                    host=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)
                fi
            fi
        fi
        # Final fallback: localhost
        if [ -z "$host" ]; then
            host="127.0.0.1"
        fi
    fi

    export CHROME_HOST="$host"
    export CHROME_PORT="$port"
}

_resolve_chrome_host

# If executed directly (not sourced), print the result
if [ "${BASH_SOURCE[0]}" = "$0" ] || [ -z "${BASH_SOURCE[0]}" ]; then
    echo "${CHROME_HOST}:${CHROME_PORT}"
fi
