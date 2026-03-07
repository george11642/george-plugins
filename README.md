# George's Claude Code Setup

A production-grade orchestration framework for Claude Code. Install this to get:

- **16 master skills** covering all development domains
- **4-mode system** (autonomous / superpowers / gsd / research)
- **Smart hooks** for context monitoring, mode switching, statusline
- **Autopilot** agent for overnight autonomous execution
- **GSD** milestone execution orchestrator

## Quick Install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/george11642/george-plugins/main/setup.sh | bash
```

## Manual Install

### 1. Add marketplace in Claude Code
```
/plugin marketplace add george11642/george-plugins
/plugin install george-setup@george-plugins
/george-setup:install
```

### 2. Add recommended marketplaces
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
/plugin install superpowers-chrome@superpowers-marketplace

/plugin marketplace add anthropics/claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install figma@claude-plugins-official
/plugin install sentry@claude-plugins-official
/plugin install github@claude-plugins-official
/plugin install stripe@claude-plugins-official
/plugin install vercel@claude-plugins-official
```

### 3. Configure settings.json

Add to `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "ENABLE_TOOL_SEARCH": "true"
  },
  "hooks": {
    "SessionStart": [
      "~/.claude/hooks/gsd-check-update.js",
      "~/.claude/hooks/framework-selector.sh"
    ],
    "UserPromptSubmit": ["~/.claude/hooks/mode-inject.sh"],
    "PostToolUse": ["~/.claude/hooks/gsd-context-monitor.js"],
    "Stop": ["~/.claude/hooks/memory-reminder.js"]
  },
  "statusLine": "~/.claude/hooks/gsd-statusline.js",
  "effortLevel": "high",
  "model": "sonnet"
}
```

## What's Included

### Plugins

| Plugin | Description |
|--------|-------------|
| `george-setup` | Core setup: skills, hooks, modes, CLAUDE.md |
| `ralph-gsd` | ROADMAP-driven milestone execution orchestrator |
| `autopilot` | Autonomous overnight coding agent |

### 16 Master Skills

Automatically installed to `~/.claude/skills/`:

| Skill | Domain |
|-------|--------|
| `python-dev` | Python, FastAPI, Django, async, packaging |
| `js-ts-dev` | JavaScript, TypeScript, Node.js, React |
| `shell-dev` | Bash/Zsh scripting, systemd, automation |
| `ui-design` | Web/mobile UI, design systems, accessibility |
| `data-viz` | Matplotlib, Plotly, D3, dashboards |
| `backend-api` | REST, GraphQL, microservices, webhooks |
| `presentations` | Slides, LaTeX posters, paper-to-web |
| `scientific-research` | Academic writing, citations, statistics |
| `seo-master` | AI SEO, schema markup, programmatic content |
| `cloud-devops` | Docker, Kubernetes, Terraform, CI/CD |
| `database` | PostgreSQL, SQL optimization, migrations |
| `ml-data` | PyTorch, RAG, MLOps, model serving |
| `expo-dev` | React Native, Expo, EAS, OTA updates |
| `security-appsec` | OWASP, JWT, OAuth2, secrets management |
| `ios-dev` | SwiftUI, async/await, App Store |
| `android-dev` | Jetpack Compose, Kotlin, Play Store |

### 4-Mode System

Switch modes by saying "switch to X" in conversation:

| Mode | Description |
|------|-------------|
| `autonomous` | Ship fast, minimal gates (default) |
| `superpowers` | Brainstorm → design → TDD → execution |
| `gsd` | ROADMAP-driven milestone execution |
| `research` | Read-only deep analysis |

### CLAUDE.md (Orchestrator Rules)

Installs a CLAUDE.md with:
- Strict delegation: Claude orchestrates, agents implement
- 3-tier dispatch: T1 (single) → T2 (parallel) → T3 (teams)
- Pre-authorized browser, git, and file operations
- Anti-pattern enforcement

### Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `framework-selector.sh` | SessionStart | Mode menu on greeting |
| `mode-inject.sh` | UserPromptSubmit | Inject active mode rules |
| `gsd-check-update.js` | SessionStart | Check GSD update |
| `gsd-context-monitor.js` | PostToolUse | Warn agents on low context |
| `gsd-statusline.js` | StatusLine | Model, task, context bar |
| `memory-reminder.js` | Stop | Remind to update MEMORY.md |

### Optional: MCP Servers

See `plugins/george-setup/mcp-servers/` for:
- **gemini-mcp** — Google Gemini integration (chat, vision, search, TTS)
- **latex-mcp** — LaTeX document compilation
- **ios-simulator-mcp** — iOS Simulator control

## Philosophy

This setup enforces an **orchestrator pattern**: Claude is a PM/architect that dispatches specialized agents. Claude never reads files directly, never writes code directly — it always delegates. This:

- Keeps the main context clean
- Enables true parallelism
- Makes work verifiable and auditable
- Scales to complex multi-day projects
