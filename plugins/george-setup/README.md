# george-setup

Complete Claude Code power-user setup: T0-T4 orchestration engine, context-aware hooks, MCP server sources, and a one-command installer.

## What's Included

### Orchestration Engine (Auto-loaded Skill)
A 5-tier task routing system that turns Claude Code into a disciplined agent orchestrator:
- **T0**: Inline edits (< 5 lines)
- **T1**: Single agent dispatch
- **T2**: Parallel independent agents
- **T3**: Coordinated agent teams with shared task lists
- **T4**: Iterative autonomous loops

Plus: context protection rules, model strategy (Opus for orchestration, Sonnet for execution, Haiku for search), anti-patterns, and error recovery.

### Hooks
- **Context Monitor**: Tracks context window usage and warns before overflow
- **Statusline**: Shows current task, git branch, and agent status in the terminal
- **Memory Reminder**: Prompts you to save learnings at natural breakpoints

### MCP Servers (Source Code)
- **gemini-mcp**: Google Gemini API integration (requires API key)
- **ios-simulator-mcp**: iOS Simulator control (macOS only)
- **latex-mcp**: LaTeX document compilation

### Install Command
Run `/george-setup:install` for automated setup of CLAUDE.md, memory, scripts, MCP servers, and settings.

## Quick Start

```bash
# Already in Claude Code:
/plugin marketplace add george11642/george-plugins
/plugin install george-setup@george-plugins

# Full setup:
/george-setup:install

# Or minimal (orchestration engine only):
/george-setup:install --minimal
```

## Requirements

- Node.js 18+
- Python 3.8+ (for latex-mcp)
- Claude Code CLI

## License

MIT
