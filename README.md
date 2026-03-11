# George's Claude Code Framework

A production-grade orchestration framework for Claude Code with 36 domain skills, 22 hooks, 2-mode autonomy system, RTK token optimization, and autopilot supervisor.

## Architecture

```
                    +-----------------+
                    |   CLAUDE.md     |  Global orchestrator rules
                    | (always loaded) |  Delegation, dispatch, verification
                    +-----------------+
                           |
              +------------+------------+
              |                         |
     +--------v--------+      +--------v--------+
     |   behavior.json |      |  settings.json  |
     | autonomy: auto  |      | hooks, plugins, |
     | toggles: r/o    |      | MCP, env vars   |
     +-----------------+      +-----------------+
              |                         |
    +---------+---------+     +---------+---------+
    |                   |     |                   |
+---v---+          +----v----+               +----v----+
| Modes |          |  Hooks  |               | Skills  |
| 2-mode|          | 22 active|              | 36 total|
+-------+          +----------+              +---------+
                        |                         |
              +---------+---------+    +----------+----------+
              |    |    |    |    |    |     |     |     |   |
            boot router gate  RTK  ... L1   L2    L3   ...
```

### 2-Mode System

Controlled via `behavior.json`:

| Mode | Behavior |
|------|----------|
| **autonomous** | Never ask, never checkpoint. Proceed on everything. Only escalate payments. |
| **guided** | Checkpoint before destructive/irreversible actions. Confirm at major milestones. Still autonomous on non-destructive work. |

Switch modes: `/mode guided`, `/mode autonomous`, `/mode readonly` (toggle)

### 3-Tier Skill System (36 skills)

| Tier | Count | Purpose | Examples |
|------|-------|---------|----------|
| **L1 Meta** | 2 | Framework control | mode, router |
| **L2 Domain** | 13 | Full-stack dev domains | web-frontend, backend-data, python-dev |
| **L3 Atomic** | 15+ | Single-purpose tools | deploy-convex, git-workflow, mcp-gemini |
| **Utility** | 6 | Framework utilities | completion-council, consolidate-memory, dashboard |

### Hook Pipeline (22 hooks)

Hooks fire at specific lifecycle events. See [MANIFEST.md](MANIFEST.md) for the complete catalog.

| Event | Hooks |
|-------|-------|
| **SessionStart** | boot.js, gsd-check-update.js |
| **UserPromptSubmit** | router.js, gate-enforcer.js |
| **PreToolUse** | dangerous-cmd-block.js, rtk-rewrite.sh, readonly-guard.js, convention-check.js |
| **PostToolUse** | context-tracker.js, self-heal.js, mid-session-skill-loader.js, budget-breaker.js, sycophancy-check.js |
| **Stop** | quality-gate.js, screenshot-verify.js |
| **PreCompact** | precompact-handoff.js |
| **StatusLine** | statusline.js |

### RTK (Rust Token Killer)

Transparent CLI proxy that rewrites commands (e.g., `git status` -> `rtk git status`) for 60-90% token savings. The `rtk-rewrite.sh` hook handles this automatically.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/george11642/george-plugins/main/setup.sh | bash
```

## Manual Install

### 1. Add marketplace and install core plugin
```
/plugin marketplace add george11642/george-plugins
/plugin install george-setup@george-plugins
/george-setup:install
```

### 2. Recommended plugins
```
# Browser automation (third-party sites, personal auth)
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers-chrome@superpowers-marketplace

# GSD milestone execution
/plugin install ralph-gsd@george-plugins

# LSP support
/plugin marketplace add anthropics/claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
/plugin install pyright-lsp@claude-plugins-official
```

### 3. Configure settings.json

The install command copies `templates/settings-template.json` to `~/.claude/settings.json`. Review and adjust paths.

### 4. Configure behavior.json

Copy `templates/behavior.json` to `~/.claude/behavior.json`:
```json
{
  "autonomy": "autonomous",
  "toggles": { "readonly": false }
}
```

## What's Included

### Plugins

| Plugin | Status | Description |
|--------|--------|-------------|
| `george-setup` | **Core** | Skills, hooks, modes, CLAUDE.md, RTK |
| `ralph-gsd` | Enabled | ROADMAP-driven milestone execution orchestrator |
| `autopilot` | Available | Autonomous overnight coding agent (systemd supervisor) |
| `ralph-marketer-v2` | Available | Marketing automation agent |

### Enabled Plugins (in settings.json)

| Plugin | Source |
|--------|--------|
| `superpowers-chrome` | superpowers-marketplace |
| `ralph-gsd` | george-plugins |
| `typescript-lsp` | claude-plugins-official |
| `pyright-lsp` | claude-plugins-official |

### Disabled Plugins (with reasons)

| Plugin | Reason |
|--------|--------|
| `context7` | Not part of minimal default set |
| `superpowers` | Absorbed into process overlays |
| `claude-session-driver` | Replaced by orchestrator skill |
| `claude-code-setup` | One-time use |
| `episodic-memory` | Replaced by progressive memory in behavior.json |
| `agent-sdk-dev` | Not essential |
| `code-simplifier` | Absorbed into domain skills |
| `content-marketing` | Not essential |
| `debugging-toolkit` | Absorbed into domain skills |
| `developer-essentials` | Absorbed into domain skills |
| `framework-migration` | Not essential |
| `frontend-mobile-development` | Absorbed into domain skills |
| `javascript-typescript` | Absorbed into domain skills |
| `python-development` | Absorbed into domain skills |
| `security-guidance` | Absorbed into domain skills |
| `shell-scripting` | Absorbed into domain skills |
| `hookify` | Extra command surface |
| `commit-commands` | Extra git command surface |
| `plugin-dev` | Plugin authoring helpers |
| `sentry` | Enable only when needed |
| `stripe` | Enable only when needed |
| `posthog` | Enable only when needed |
| `figma` | Enable only when needed |
| `claude-md-management` | Extra authoring helpers |
| `github` | gh CLI covers day-to-day work |
| `supabase` | MCP handles directly |
| `ui-design` | Absorbed into domain skills |
| `vercel` | Not essential for daily use |

### MCP Servers

| Server | Type | Status |
|--------|------|--------|
| `clerk` | HTTP (`https://mcp.clerk.com/mcp`) | **Active** |
| `gemini-mcp` | Local (stdio) | Disabled |
| `ios-simulator` | Local (stdio) | Disabled |
| `latex` | Local (stdio) | Disabled |
| `stitch` | External | Disabled |

### Autopilot

Systemd service (`claude-supervisor.service`) that reads `~/.claude/autopilot/queue.json`, invokes `claude -p` per task, tracks budget in `mission.json`, logs to `audit.jsonl`.

CLI: `~/.claude/scripts/autopilot-queue.sh` -- add/list/remove/status/stop/resume/clean/audit

## Philosophy

This setup enforces an **orchestrator pattern**: Claude is a PM/architect that dispatches specialized agents. Claude never reads implementation files directly, never writes code directly -- it always delegates. This:

- Keeps the main context clean
- Enables true parallelism via agent teams
- Makes work verifiable and auditable
- Scales to complex multi-day projects
- Prevents sycophantic rubber-stamping (sycophancy-check hook)
- Enforces token budgets (budget-breaker hook)
- Preserves session state across compactions (precompact-handoff hook)

## File Structure

```
plugins/
  george-setup/          # Core framework
    hooks/               # 22 lifecycle hooks + lib/
    skills/              # 36 domain skills (SKILL.md + references/)
    scripts/             # Automation scripts
    templates/           # CLAUDE.md, settings.json, behavior.json, RTK.md
    modes/               # autonomous.txt, guided.txt
    commands/            # Plugin slash commands
    docs/                # Setup documentation
  autopilot/             # Autonomous execution agent
  ralph-gsd/             # Milestone execution orchestrator
  ralph-marketer-v2/     # Marketing automation
```

See [MANIFEST.md](MANIFEST.md) for the complete inventory of every component.
