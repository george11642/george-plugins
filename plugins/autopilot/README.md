# Autopilot — Autonomous Overnight Coding Agent

Give it a mission. Walk away. Come back to a better codebase.

Autopilot runs Claude Code in a **fresh-instance loop** — each iteration gets a clean 200K context window, reads its state from files, completes one task, commits, and hands off to the next iteration. It can run for hours without human intervention.

## Quick Start

```bash
# Install from george-plugins marketplace
/plugin install autopilot@george-plugins

# Start a mission
/autopilot "Add comprehensive test coverage to the auth module"

# Check progress
/autopilot-status

# Stop gracefully
/autopilot-stop

# Resume later
/autopilot-resume

# Get final report
/autopilot-report
```

## Modes

### Mission (default)
Give it a goal, it decomposes into tasks and works through them.
```
/autopilot "Migrate all API routes from pages/ to app/ router"
```

### Improve
No goal needed — it scans the codebase for issues and fixes the highest-priority ones.
```
/autopilot --mode improve
```

### Execute
Feed it an existing plan file (GSD-compatible).
```
/autopilot --mode execute --plan .planning/ROADMAP.md
```

### Research
Deep research mode — produces a comprehensive report.
```
/autopilot --mode research "How to implement real-time WebSocket subscriptions with Convex"
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--mode` | `mission` | `mission`, `improve`, `execute`, `research` |
| `--hours` | `8` | Maximum runtime in hours |
| `--max-iterations` | `50` | Safety cap on loop iterations |
| `--parallel` | `3` | Max parallel subagents per iteration |
| `--scope` | all | Comma-separated directories to focus on |
| `--plan` | — | Plan file path (required for execute mode) |
| `--dry-run` | — | Preview without executing |

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  autopilot.sh                     │
│              (Bash outer loop)                    │
│                                                   │
│  while !should_stop; do                          │
│    prompt = build_from(.autopilot/*)             │
│    claude -p "$prompt" --dangerously-skip-perms  │
│    check_stop_signals                            │
│  done                                            │
└──────────────────────────────────────────────────┘
         │ spawns fresh instance each iteration
         ▼
┌──────────────────────────────────────────────────┐
│              Claude Instance                      │
│         (Fresh 200K context window)              │
│                                                   │
│  1. Orient  → Read .autopilot/ state files       │
│  2. Research → Spawn researcher subagent         │
│  3. Implement → Spawn implementer subagent       │
│  4. Verify  → Spawn verifier subagent            │
│  5. Commit  → git add + commit + push            │
│  6. Update  → Write progress.json + handoff.md   │
│  7. Signal  → AUTOPILOT_STATUS: COMPLETE         │
└──────────────────────────────────────────────────┘
         │ writes state to disk
         ▼
┌──────────────────────────────────────────────────┐
│              .autopilot/ (File State)             │
│                                                   │
│  mission.json   — The user's goal (immutable)    │
│  progress.json  — Task list + completion status   │
│  handoff.md     — Context for next iteration     │
│  log.md         — Append-only activity log       │
│  loop.log       — Raw bash loop output           │
│  loop.pid       — Process ID for stop/status     │
│  iterations/    — Per-iteration Claude output     │
└──────────────────────────────────────────────────┘
```

## Key Design Decisions

1. **Fresh context per iteration** — Unlike Stop-hook loops that accumulate context garbage, each iteration starts clean. This enables truly unlimited runtime.

2. **File-as-memory** — All state lives in `.autopilot/`. Context windows are ephemeral; files are durable. Inspired by the Ralph Wiggum pattern.

3. **One task per iteration** — Quality over quantity. Each iteration focuses on a single task, verifies it, and commits. No half-done work.

4. **Multi-agent per iteration** — Each Claude instance spawns specialized subagents (researcher, implementer, verifier) in isolated contexts. The main instance orchestrates.

5. **Git-as-progress** — Commits are the ultimate proof of work. If it's not committed, it didn't happen.

6. **Handoff protocol** — Each iteration writes what the next one needs to know. Failed approaches are the most valuable handoff — they prevent re-doing dead ends.

## Inspired By

- [Ralph Wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) — The foundational "run Claude in a loop" pattern
- [Anthropic's autonomous-coding quickstart](https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding) — Initializer + Coder agent split
- [continuous-claude](https://github.com/AnandChowdhary/continuous-claude) — SHARED_TASK_NOTES.md for cross-iteration memory
- [OpenHands](https://github.com/OpenHands/OpenHands) — Event-sourced agent architecture
- [Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus) — Filesystem as unlimited external memory
- [Superpowers/GSD](https://github.com/obra/superpowers) — Skill-based progressive disclosure

## License

MIT
