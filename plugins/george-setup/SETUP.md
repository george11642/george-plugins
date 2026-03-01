# New Machine Setup Guide

Complete step-by-step instructions for replicating George's Claude Code setup on a new machine.

## Prerequisites

Install these before starting:

```bash
# Node.js (v20+)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Git, curl, python3
sudo apt-get install -y git curl python3 python3-pip

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
```

## Step 1: Clone george-plugins repo

```bash
mkdir -p ~/.claude/plugins/marketplaces
git clone git@github.com:george11642/george-plugins.git ~/.claude/plugins/marketplaces/george-plugins
```

## Step 2: Register george-plugins marketplace

```bash
claude plugins marketplace add george-plugins george11642/george-plugins
```

Or manually register via Claude Code settings.

## Step 3: Run the install script

```bash
bash ~/.claude/plugins/marketplaces/george-plugins/plugins/george-setup/scripts/install.sh
```

This will:
- Copy CLAUDE.md to `~/.claude/CLAUDE.md`
- Install hooks to `~/.claude/hooks/`
- Symlink scripts to `~/.claude/scripts/`
- Create `~/.claude/memory/orchestration.md`
- Create required directories

## Step 4: Install all marketplaces

Register these marketplaces in Claude Code:

| Marketplace | GitHub URL | Register command |
|-------------|------------|-----------------|
| george-plugins | git@github.com:george11642/george-plugins.git | `claude plugins marketplace add george-plugins george11642/george-plugins` |
| claude-plugins-official | git@github.com:anthropics/claude-plugins-official.git | `claude plugins marketplace add claude-plugins-official anthropics/claude-plugins-official` |
| superpowers-marketplace | git@github.com:obra/superpowers-marketplace.git | `claude plugins marketplace add superpowers-marketplace obra/superpowers-marketplace` |
| claude-code-workflows | https://github.com/wshobson/agents.git | `claude plugins marketplace add claude-code-workflows wshobson/agents` |
| thedotmack | git@github.com:thedotmack/claude-mem.git | `claude plugins marketplace add thedotmack thedotmack/claude-mem` |

## Step 5: Enable plugins

Enable these plugins (they should be enabled by default once marketplaces are registered):

**From george-plugins:**
- `autopilot@george-plugins`
- `ralph-gsd@george-plugins`

**From claude-plugins-official:**
- `agent-sdk-dev@claude-plugins-official`
- `claude-code-setup@claude-plugins-official`
- `code-simplifier@claude-plugins-official`
- `commit-commands@claude-plugins-official`
- `context7@claude-plugins-official`
- `feature-dev@claude-plugins-official`
- `figma@claude-plugins-official`
- `github@claude-plugins-official`
- `hookify@claude-plugins-official`
- `playwright@claude-plugins-official`
- `plugin-dev@claude-plugins-official`
- `posthog@claude-plugins-official`
- `pr-review-toolkit@claude-plugins-official`
- `pyright-lsp@claude-plugins-official`
- `security-guidance@claude-plugins-official`
- `sentry@claude-plugins-official`
- `stripe@claude-plugins-official`
- `supabase@claude-plugins-official`
- `typescript-lsp@claude-plugins-official`
- `vercel@claude-plugins-official`

**From superpowers-marketplace:**
- `claude-session-driver@superpowers-marketplace`
- `elements-of-style@superpowers-marketplace`
- `superpowers@superpowers-marketplace`
- `superpowers-chrome@superpowers-marketplace`
- `superpowers-lab@superpowers-marketplace`

**From claude-code-workflows:**
- `content-marketing@claude-code-workflows`
- `debugging-toolkit@claude-code-workflows`
- `developer-essentials@claude-code-workflows`
- `framework-migration@claude-code-workflows`
- `frontend-mobile-development@claude-code-workflows`
- `javascript-typescript@claude-code-workflows`
- `python-development@claude-code-workflows`
- `shell-scripting@claude-code-workflows`
- `ui-design@claude-code-workflows`

## Step 6: Configure settings.json

```bash
cp ~/.claude/plugins/marketplaces/george-plugins/plugins/george-setup/templates/settings-template.json ~/.claude/settings.json
```

Edit `~/.claude/settings.json` and fill in the placeholders (search for `YOUR_`).

## Step 7: Configure MCP servers

```bash
cp ~/.claude/plugins/marketplaces/george-plugins/plugins/george-setup/templates/mcp-template.json ~/.claude/.mcp.json
```

Edit `~/.claude/.mcp.json` and replace all `YOUR_*_HERE` placeholders.

## Step 8: Manual credential setup

### Gemini API Key
1. Go to https://aistudio.google.com/app/apikey
2. Create a new API key
3. Set in `~/.claude/.mcp.json` for the Gemini MCP server

### GitHub CLI auth
```bash
gh auth login
# Follow prompts, choose GitHub.com, SSH
```

### LaTeX (for LaTeX MCP)
```bash
sudo apt-get install -y texlive-full
# Or minimal: sudo apt-get install -y texlive
```

### Build MCP servers

For any MCP servers that require building (check `~/.claude/.mcp.json` for node-based servers):

```bash
# Example for a typical MCP server
cd /path/to/mcp-server
npm install
npm run build
```

Check each server's directory for its specific build instructions.

### Chrome for Superpowers (WSL-specific)

The Superpowers Chrome MCP requires Chrome to be accessible from WSL. On Windows + WSL2:

1. Install Google Chrome on Windows
2. The `superpowers-chrome-mcp-wrapper.sh` script handles the WSL↔Windows bridge
3. Check `~/.claude/scripts/resolve-wsl-chrome-host.sh` for the host resolution logic

If Chrome is not found, the script may need the Windows Chrome path updated:
```bash
# Typical Windows Chrome path visible from WSL:
/mnt/c/Program Files/Google/Chrome/Application/chrome.exe
```

### Skills / .agents directory

The `~/.agents/` directory contains custom agent skills. This directory does not currently have a git remote tracked.

To replicate, manually copy the contents from the source machine:
```bash
# On source machine:
rsync -av ~/.agents/ user@newmachine:~/.agents/

# Or copy to a git repo and clone on new machine
```

## Step 9: Verify setup

Run in Claude Code:
```
/autopilot:account-check
```

This will verify all configured services (Stripe, PostHog, Sentry, Supabase, etc.) are accessible.

Also check that hooks are working:
- The memory reminder should fire at session end
- The context monitor should fire after tool calls
- The status line should show GSD status

## Troubleshooting

**Hook not firing:** Check that hook paths in `settings.json` use `$HOME` or absolute paths. WSL paths must be correct.

**MCP server not connecting:** Run the server command manually from terminal to see errors. Usually a missing `npm install` or wrong API key.

**Superpowers Chrome failing:** On WSL, run `~/.claude/scripts/patch-chrome-plugin-configs.sh` to update Chrome paths.

**Plugin not found:** Make sure the marketplace is registered and `claude plugins update` has been run.
