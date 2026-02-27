# george-plugins

Claude Code plugin marketplace by [George Teifel](https://github.com/george11642). Power-user tools for autonomous development, orchestration, and marketing.

## Quick Start

```bash
# Add the marketplace
# In Claude Code:
/plugin marketplace add george11642/george-plugins

# Install the setup plugin (recommended first)
/plugin install george-setup@george-plugins

# Run full setup
/george-setup:install
```

Or bootstrap before opening Claude Code:
```bash
curl -fsSL https://raw.githubusercontent.com/george11642/george-plugins/main/setup.sh | bash
```

## Plugins

### george-setup
**Complete Claude Code power-user setup.** Installs the T0-T4 orchestration engine, context-aware hooks, MCP server sources, and utility scripts with a single command.

- Auto-loaded skill: 5-tier task routing (T0 inline → T4 autonomous loops)
- Hooks: context monitor, statusline, memory reminders
- MCP servers: Gemini, LaTeX, iOS Simulator
- Command: `/george-setup:install`

[Read more →](plugins/george-setup/README.md)

### ralph-gsd
**Autonomous milestone execution orchestrator.** Parses dependency graphs from ROADMAP.md and dispatches independent phases concurrently. Handles research, planning, execution, and verification.

- Commands: `/gsd:new-project`, `/gsd:execute-phase`, `/gsd:plan-phase`, `/gsd:verify-work`, and 20+ more
- Agents: researcher, planner, executor, verifier, integration checker

[Read more →](plugins/ralph-gsd/README.md)

### autopilot
**Overnight autonomous coding agent.** Give it a mission, walk away for hours, come back to a better codebase. Fresh-context loop pattern with file-based memory for unlimited runtime.

- Modes: mission-driven, codebase improvement, plan execution, deep research
- Commands: `/autopilot`, `/autopilot-status`, `/autopilot-stop`, `/autopilot-resume`

[Read more →](plugins/autopilot/README.md)

### ralph-marketer-v2
**Autonomous content marketing pipeline.** Auto-detects tech stack, runs headless content loops, manages SQLite pipeline, publishes to multiple platforms.

- Targets: Supabase, Medium, Dev.to, markdown, MDX
- Commands: `/ralph-run`, `/ralph-status`, `/ralph-publish`

[Read more →](plugins/ralph-marketer-v2/README.md)

## Documentation

- [Recommended Plugins](plugins/george-setup/docs/recommended-plugins.md) — Curated list of 40+ Claude Code plugins
- [Manual Setup Steps](plugins/george-setup/docs/manual-steps.md) — API keys and credentials
- [Minimal Installation](plugins/george-setup/docs/minimal-install.md) — Orchestration engine only

## Setup Options

| Path | What You Get | Time |
|------|-------------|------|
| **Minimal** | Orchestration engine + hooks | 30 seconds |
| **Full** | + MCP servers, scripts, settings | 2-3 minutes |
| **Bootstrap** | Pre-Claude-Code setup via curl | 1 minute |

## Requirements

- Claude Code CLI
- Node.js 18+
- Python 3.8+ (for latex-mcp, optional)
- Git

## License

MIT
