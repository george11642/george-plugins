#!/usr/bin/env bash
# Install autonomous ops files to ~/.claude/
# Called by SessionStart hook

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Install agents (symlink, don't overwrite non-plugin files)
mkdir -p "$CLAUDE_DIR/agents"
for agent_file in "$PLUGIN_DIR/agents/"*.md; do
    [[ ! -f "$agent_file" ]] && continue
    base="$(basename "$agent_file")"
    # Only install our agents (check by name pattern)
    case "$base" in
        sentry-autofix.md|posthog-analyzer.md|marketing-agent.md|legal-doc-generator.md|security-reviewer.md|saas-strategist.md|evaluator.md|canary-deployer.md)
            if [[ ! -f "$CLAUDE_DIR/agents/$base" ]] || [[ -L "$CLAUDE_DIR/agents/$base" ]]; then
                ln -sf "$agent_file" "$CLAUDE_DIR/agents/$base"
            fi
            ;;
    esac
done

# Install scripts
mkdir -p "$CLAUDE_DIR/scripts"
for script_file in "$PLUGIN_DIR/scripts/"*.sh; do
    [[ ! -f "$script_file" ]] && continue
    base="$(basename "$script_file")"
    case "$base" in
        cost-tracker.sh|canary-deploy.sh|sentry-scan.sh|posthog-analyze.sh)
            ln -sf "$script_file" "$CLAUDE_DIR/scripts/$base"
            ;;
    esac
done

# Install knowledge base (copy, don't overwrite)
mkdir -p "$CLAUDE_DIR/autopilot-knowledge"
for config_file in "$PLUGIN_DIR/config/"*.json; do
    [[ ! -f "$config_file" ]] && continue
    base="$(basename "$config_file")"
    [[ "$base" == "account-inventory.json" ]] && continue  # handled separately
    if [[ ! -f "$CLAUDE_DIR/autopilot-knowledge/$base" ]]; then
        cp "$config_file" "$CLAUDE_DIR/autopilot-knowledge/$base"
    fi
done

# Install account inventory (copy, don't overwrite)
if [[ -f "$PLUGIN_DIR/config/account-inventory.json" ]] && [[ ! -f "$CLAUDE_DIR/account-inventory.json" ]]; then
    cp "$PLUGIN_DIR/config/account-inventory.json" "$CLAUDE_DIR/account-inventory.json"
fi
