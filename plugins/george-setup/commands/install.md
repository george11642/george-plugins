---
description: "Install George's complete Claude Code setup: orchestration engine, hooks, MCP servers, and scripts"
---

# /george-setup:install

You are installing the george-setup power-user configuration. Follow these steps carefully.

## Arguments
- `--minimal` — Only install the CLAUDE.md template (skip MCP servers, scripts, settings merge)
- `--dry-run` — Show what would be installed without making changes
- No arguments — Full installation

## Pre-flight Checks

1. Verify prerequisites:
   ```bash
   node --version  # Required: Node.js 18+
   python3 --version  # Required for latex-mcp
   ```
2. Detect OS: check `uname -s` for Darwin (macOS) vs Linux (includes WSL2)
3. Check if WSL2: `grep -qi microsoft /proc/version 2>/dev/null`

If any prerequisite fails, inform the user what's missing and which components won't work.

## Step 1: Install CLAUDE.md Template

1. Check if `~/.claude/CLAUDE.md` already exists
2. If it exists, back it up: `cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup.$(date +%s)`
3. Locate the template at `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template` (where CLAUDE_PLUGIN_ROOT is the george-setup plugin directory)
4. Copy it: `cp "${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template" ~/.claude/CLAUDE.md`
5. Tell the user they can customize `~/.claude/CLAUDE.md` — it's their file now

**For `--minimal` installs, stop here.**

## Step 2: Install Orchestration Memory

1. Create `~/.claude/memory/` if it doesn't exist
2. If `~/.claude/memory/orchestration.md` doesn't exist, copy the template:
   ```bash
   cp "${CLAUDE_PLUGIN_ROOT}/templates/orchestration-memory.md" ~/.claude/memory/orchestration.md
   ```
3. If it already exists, skip (don't overwrite user's memory)

## Step 3: Copy Wrapper Scripts

1. Create `~/.claude/scripts/` if it doesn't exist
2. Copy all scripts from `${CLAUDE_PLUGIN_ROOT}/scripts/` to `~/.claude/scripts/`:
   - `latex-mcp-wrapper.sh`
   - `playwright-mcp-wrapper.sh`
   - `superpowers-chrome-mcp-wrapper.sh`
   - `resolve-wsl-chrome-host.sh`
   - `patch-chrome-plugin-configs.sh`
3. Make them executable: `chmod +x ~/.claude/scripts/*.sh`
4. Skip scripts that already exist (don't overwrite user customizations)

## Step 4: Build MCP Servers

### gemini-mcp (TypeScript)
```bash
cd "${CLAUDE_PLUGIN_ROOT}/mcp-servers/gemini-mcp"
npm ci
npm run build
# Copy built artifacts to ~/.claude/mcp-servers/gemini-mcp/
mkdir -p ~/.claude/mcp-servers/gemini-mcp
cp -r dist package.json node_modules ~/.claude/mcp-servers/gemini-mcp/
cp -r src ~/.claude/mcp-servers/gemini-mcp/  # keep source for reference
```

### ios-simulator-mcp (macOS only)
Only if on macOS (`uname -s` = Darwin):
```bash
cd "${CLAUDE_PLUGIN_ROOT}/mcp-servers/ios-simulator-mcp"
npm ci
npm run build
mkdir -p ~/.claude/mcp-servers/ios-simulator-mcp
cp -r dist package.json node_modules ~/.claude/mcp-servers/ios-simulator-mcp/
```

### latex-mcp (Python)
```bash
cd "${CLAUDE_PLUGIN_ROOT}/mcp-servers/latex-mcp"
pip install -r requirements.txt  # or: uv pip install -r requirements.txt
mkdir -p ~/.claude/mcp-servers/latex-mcp
cp -r . ~/.claude/mcp-servers/latex-mcp/
```

If any build fails, report the error but continue with other components.

## Step 5: Merge Settings

Run the settings merger:
```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/merge-settings.cjs"
```

This adds:
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env var
- MCP server entries (gemini, latex) if not already configured
- `skipDangerousModePermissionPrompt: true`

## Step 6: Summary

Print a summary of what was installed:

```
## Installation Complete

### Installed:
- [x] CLAUDE.md template (orchestration engine, context protection, model strategy)
- [x] Orchestration memory file
- [x] Wrapper scripts (5 scripts)
- [x] gemini-mcp server (built and configured)
- [x] ios-simulator-mcp server (macOS only — skipped/built)
- [x] latex-mcp server (configured)
- [x] Settings merged (env vars, MCP entries)

### Manual Steps Required:
1. **Gemini API Key**: Set `GEMINI_API_KEY` in `~/.claude/settings.json` → env section
   - Get a key at: https://aistudio.google.com/apikey
2. **Review CLAUDE.md**: Customize `~/.claude/CLAUDE.md` — update the "About Me" section
3. **Recommended plugins**: See `docs/recommended-plugins.md` for George's curated plugin list
4. **Restart Claude Code** for all changes to take effect
```

## Idempotency

This command is safe to run multiple times:
- CLAUDE.md: Backs up existing before overwriting
- Memory: Skips if already exists
- Scripts: Skips existing files
- MCP builds: Rebuilds (safe)
- Settings: Additive merge only (never overwrites existing values)
