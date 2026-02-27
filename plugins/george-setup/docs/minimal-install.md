# Minimal Installation

If you just want the orchestration engine without MCP servers or scripts, here's the lightweight path.

## What You Get

- **T0-T4 routing system** — automatic task complexity assessment and agent dispatch
- **Context protection** — hard limits that prevent context window waste
- **Model strategy** — Opus for orchestration, Sonnet for execution, Haiku for search
- **Anti-patterns** — catches common mistakes before they happen
- **Hooks** — context monitor, statusline, memory reminders (bundled with plugin)

## What You Don't Get

- MCP servers (gemini, latex, ios-simulator)
- Wrapper scripts for browser automation
- Settings merge (env vars, MCP entries)

## Steps

```bash
# 1. Add marketplace
/plugin marketplace add george11642/george-plugins

# 2. Install plugin (hooks and skill load automatically)
/plugin install george-setup@george-plugins

# 3. Install just the CLAUDE.md template
/george-setup:install --minimal
```

That's it. The orchestration skill auto-loads on every conversation. The hooks fire automatically.

## Adding Components Later

You can always run the full install later:
```
/george-setup:install
```

Or manually add individual MCP servers as needed.
