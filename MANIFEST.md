# MANIFEST

Complete inventory of every component in the george-plugins framework.

Last updated: 2026-03-11

---

## Hooks

### SessionStart

| Hook | File | Purpose | Status |
|------|------|---------|--------|
| Boot | `boot.js` | Session initialization, loads behavior.json, sets up environment | Active |
| GSD Check Update | `gsd-check-update.js` | Checks if ralph-gsd skill needs updating on session start | Active |

### UserPromptSubmit

| Hook | File | Purpose | Status |
|------|------|---------|--------|
| Router | `router.js` | Domain classification (23 domains), triggers skill loading | Active |
| Gate Enforcer | `gate-enforcer.js` | Enforces behavior.json toggles (readonly, autonomy level) | Active |

### PreToolUse

| Hook | File | Matcher | Purpose | Status |
|------|------|---------|---------|--------|
| Dangerous Command Block | `dangerous-cmd-block.js` | Bash | Blocks dangerous shell commands (rm -rf /, etc.) | Active |
| RTK Rewrite | `rtk-rewrite.sh` | Bash | Rewrites CLI commands through RTK proxy for token savings | Active |
| Readonly Guard | `readonly-guard.js` | All | Blocks writes when readonly toggle is on | Active |
| Convention Check | `convention-check.js` | All | Pre-write security and convention enforcement | Active |

### PostToolUse

| Hook | File | Purpose | Status |
|------|------|---------|--------|
| Context Tracker | `context-tracker.js` | Goal anchoring every 50 tool calls, prevents drift | Active |
| Self-Heal | `self-heal.js` | Detects failures, triggers recovery (retry/rollback/different approach) | Active |
| Mid-Session Skill Loader | `mid-session-skill-loader.js` | Dynamically loads skills mid-session when domain changes | Active |
| Budget Breaker | `budget-breaker.js` | Token budget circuit breaker, stops runaway sessions | Active |
| Sycophancy Check | `sycophancy-check.js` | Detects rubber-stamp approvals, enforces genuine review | Active |

### Stop

| Hook | File | Purpose | Status |
|------|------|---------|--------|
| Quality Gate | `quality-gate.js` | Verifies tests pass and types check before session ends | Active |
| Screenshot Verify | `screenshot-verify.js` | Visual verification of UI changes via screenshots | Active |

### PreCompact

| Hook | File | Purpose | Status |
|------|------|---------|--------|
| PreCompact Handoff | `precompact-handoff.js` | Saves session state to HANDOFF.md before context compaction (async) | Active |

### StatusLine

| Hook | File | Purpose | Status |
|------|------|---------|--------|
| Statusline | `statusline.js` | ANSI status display (model, mode, domain, context, budget) | Active |

### Support / Legacy

| Hook | File | Purpose | Status |
|------|------|---------|--------|
| Sycophancy Detector | `lib/sycophancy-detector.js` | Support library for sycophancy-check.js | Library |
| Framework Selector | `framework-selector.sh` | Legacy mode menu on greeting | Legacy |
| Mode Inject | `mode-inject.sh` | Legacy mode rules injection | Legacy |
| GSD Context Monitor | `gsd-context-monitor.js` | GSD-specific context monitoring | GSD-only |
| GSD Statusline | `gsd-statusline.js` | GSD-specific status display | GSD-only |
| Memory Reminder | `memory-reminder.js` | Reminds to update MEMORY.md on stop | Optional |
| .rtk-hook.sha256 | `.rtk-hook.sha256` | RTK hook integrity hash | Metadata |

---

## Skills

### L1 Meta (2)

| Skill | Directory | Description |
|-------|-----------|-------------|
| Mode | `mode/` | Switch behavior mode (`/mode guided`, `/mode autonomous`, `/mode readonly`). Updates behavior.json. |
| Router | (hook: `router.js`) | Domain classification across 23 domains. Implemented as a hook, not a standalone skill directory. |

### L2 Domain (13)

| Skill | Directory | Triggers |
|-------|-----------|----------|
| Web Frontend | `web-frontend/` | React, Next.js, Tailwind, SSR, RSC, accessibility, Remotion |
| Backend Data | `backend-data/` | REST, GraphQL, Node.js, Express, Fastify, pagination, webhooks |
| TypeScript Core | `typescript-core/` | Generics, conditional types, tsconfig, ESLint, build tools (Vite, Turbopack) |
| Python Dev | `python-dev/` | pyproject.toml, ruff, pyright, pytest, FastAPI, Django, asyncio, Pydantic |
| ML Data Engineering | `ml-data-engineering/` | PyTorch, scikit-learn, HuggingFace, RAG, vector DBs, MLOps, model serving |
| Cloud Infra | `cloud-infra/` | Docker, Kubernetes, Terraform, CI/CD, AWS/GCP/Azure, serverless, systemd |
| Mobile Native | `mobile-native/` | Expo, React Native, SwiftUI, Kotlin/Jetpack Compose, EAS Build |
| Security Deep | `security-deep/` | OWASP, vulnerability scanning, threat modeling, SOC2, GDPR, incident response |
| Auth Clerk | `auth-clerk/` | Clerk authentication, middleware, protected routes, webhooks, Svix |
| SEO Growth | `seo-growth/` | Technical SEO, schema markup, AI search visibility, CRO, GA4 |
| Marketing | `marketing/` | Marketing automation and content |
| Payments Stripe | `payments-stripe/` | Stripe checkout, subscriptions, webhooks, billing, Customer Portal |
| Monitoring Sentry | `monitoring-sentry/` | Sentry error monitoring, issue triage, Sentry Seer, MCP integration |

### L3 Atomic (15)

| Skill | Directory | Purpose |
|-------|-----------|---------|
| Deploy Convex | `deploy-convex/` | Convex CLI operations, schema push, dev/prod deployments |
| Deploy Modal | `deploy-modal/` | Modal worker deployment, logs, secrets, GPU endpoints |
| Deploy Vercel | `deploy-vercel/` | Vercel deployments, environment variables, custom domains |
| Git Workflow | `git-workflow/` | Commits, PRs, branches, merge conflicts, conventional commits |
| Testing Quality | `testing-quality/` | Vitest, Playwright, pytest, type-checks, coverage |
| Browser Agent | `browser-agent/` | Chrome automation, screenshots, form filling, visual verification |
| DB Convex | `db-convex/` | Convex schema, queries, mutations, actions, workflows |
| DB Supabase | `db-supabase/` | Supabase database, SQL, migrations, edge functions, RLS |
| MCP Gemini | `mcp-gemini/` | Gemini AI: image analysis, generation, search, TTS, video |
| MCP NotebookLM | `mcp-notebooklm/` | NotebookLM: source analysis, notebooks, audio overviews |
| Research Tools | `research-tools/` | YouTube search, source analysis, requirements gathering, interviews |
| Presentations Docs | `presentations-docs/` | Slides, PPTX, LaTeX posters, Beamer, speaker notes |
| Data Visualization | `data-visualization/` | Charts, plots, dashboards, Excel (openpyxl), D3, animations |
| Analytics PostHog | `analytics-posthog/` | PostHog analytics, feature flags, experiments, HogQL |
| Scientific Research | `scientific-research/` | Academic writing, statistics, grant proposals, PRISMA, causal inference |

### Utility Skills (6)

| Skill | Directory | Purpose |
|-------|-----------|---------|
| Completion Council | `completion-council/` | Multi-agent verification of work quality before declaring done |
| Consolidate Memory | `consolidate-memory/` | Deduplicates and cleans up MEMORY.md |
| Dashboard | `dashboard/` | Claude Code monitoring dashboard |
| Playwright Auth | `playwright-auth/` | Clerk Backend API sign-in tokens for headless testing |
| MCP Obsidian | `mcp-obsidian/` | Obsidian vault read/write/search via MCP |
| Ralph GSD | `ralph-gsd/` | GSD milestone execution (invokes monitor) |
| Ralph GSD Monitor | `ralph-gsd-monitor/` | Recurring monitor for GSD autonomous loops |

---

## Plugins

| Plugin | Directory | Version | Purpose | Status |
|--------|-----------|---------|---------|--------|
| george-setup | `plugins/george-setup/` | - | Core framework: hooks, skills, modes, templates, scripts | Active |
| autopilot | `plugins/autopilot/` | 1.2.0 | Autonomous overnight coding agent with systemd supervisor | Available |
| ralph-gsd | `plugins/ralph-gsd/` | - | ROADMAP-driven milestone execution orchestrator | Active (enabled) |
| ralph-marketer-v2 | `plugins/ralph-marketer-v2/` | - | Marketing automation agent | Available |

---

## MCP Servers

| Server | Type | URL/Path | Status |
|--------|------|----------|--------|
| Clerk | HTTP | `https://mcp.clerk.com/mcp` | **Active** |
| Gemini MCP | Local (stdio) | `~/.claude/mcp-servers/gemini-mcp/` | Disabled |
| iOS Simulator | Local (stdio) | Via wrapper script | Disabled |
| LaTeX | Local (stdio) | Via wrapper script | Disabled |
| Stitch | External | - | Disabled |

---

## Scripts

| Script | Purpose |
|--------|---------|
| `autopilot-queue.sh` | Autopilot queue CLI: add/list/remove/status/stop/resume/clean/audit |
| `claude-supervisor.sh` | Systemd supervisor: reads queue, invokes `claude -p`, tracks budget |
| `ralph-gsd-monitor.sh` | GSD progress monitor, restarts if stopped, resolves deferred items |
| `ralph-gsd.sh` | Ralph GSD execution script |
| `patch-chrome-plugin-configs.sh` | Patches Chrome plugin configs on session start |
| `chrome-devtools-mcp-wrapper.sh` | Chrome DevTools MCP wrapper |
| `superpowers-chrome-mcp-wrapper.sh` | Superpowers Chrome MCP wrapper |
| `resolve-wsl-chrome-host.sh` | Resolves Chrome host IP for WSL2 |
| `playwright-mcp-wrapper.sh` | Playwright MCP wrapper |
| `obsidian-mcp-wrapper.sh` | Obsidian MCP wrapper |
| `latex-mcp-wrapper.sh` | LaTeX MCP wrapper |
| `ios-sim-health.sh` | iOS Simulator health check |
| `ios-sim-start.sh` | iOS Simulator start |
| `ios-sim-stop.sh` | iOS Simulator stop |
| `consolidate-memory.py` | Python script to consolidate/deduplicate MEMORY.md |
| `vnc_capture.py` | VNC screenshot capture |
| `vnc_interact.py` | VNC interaction (click, type, scroll) |

---

## Config Files

| File | Location | Purpose |
|------|----------|---------|
| `behavior.json` | `~/.claude/behavior.json` | Autonomy mode (autonomous/guided) and toggles (readonly) |
| `settings.json` | `~/.claude/settings.json` | Hooks, plugins, MCP servers, env vars, permissions |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Global orchestrator rules (always loaded) |
| `RTK.md` | `~/.claude/RTK.md` | RTK token optimization instructions |
| `MEMORY.md` | Per-project | Episodic memory (gotchas, patterns, architecture notes) |

---

## Templates (in `plugins/george-setup/templates/`)

| Template | Target | Description |
|----------|--------|-------------|
| `global-claude-md.md` | `~/.claude/CLAUDE.md` | Orchestrator identity, delegation rules, dispatch protocol, verification |
| `settings-template.json` | `~/.claude/settings.json` | Complete hook wiring, plugin config, MCP servers, env vars |
| `behavior.json` | `~/.claude/behavior.json` | Default autonomy mode and toggles |
| `RTK.md` | `~/.claude/RTK.md` | RTK usage instructions and meta commands |

---

## Modes (in `plugins/george-setup/modes/`)

| Mode | File | Behavior |
|------|------|----------|
| Autonomous | `autonomous.txt` | Never ask, never checkpoint. Only escalate payments. |
| Guided | `guided.txt` | Checkpoint before destructive actions. Confirm at milestones. |
