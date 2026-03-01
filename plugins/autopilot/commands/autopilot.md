---
name: autopilot
description: "Start autonomous coding loop. Modes: mission (default), improve, execute, research, evolve, build-saas, marketing."
argument-hint: '"mission description" [--mode mission|improve|execute|research|evolve|build-saas|marketing] [--hours N] [--max-iterations N] [--parallel N] [--milestones N] [--focus "areas"] [--budget DOLLARS] [--phase-timeout SECS] [--dry-run]'
---

# /autopilot — Autonomous Overnight Coding Agent

Start a fully autonomous coding loop that runs for hours without human intervention.

## What to do

### 1. Parse arguments

Extract from `$ARGUMENTS`:
- **Mission text**: The quoted string (required for mission/research/build-saas modes; optional for evolve/improve/marketing)
- `--mode`: `mission` (default) | `improve` | `execute` | `research` | `evolve` | `build-saas` | `marketing`
- `--hours`: Max runtime in hours (default: 8)
- `--max-iterations`: Safety limit per session (default: 50)
- `--parallel`: Max parallel subagents per iteration (default: 3)
- `--plan`: Path to existing plan file (for execute mode, defaults to .planning/ROADMAP.md)
- `--scope`: Limit to specific directories (comma-separated)
- `--skip-discuss`: In execute mode, skip GSD discuss phases (go straight to plan)
- `--milestones N`: In evolve mode, max milestones to complete (default: unlimited)
- `--focus AREAS`: In evolve mode, comma-separated focus areas for the strategist
  e.g., `"testing,security"` or `"performance,reliability,observability"`
- `--budget DOLLARS`: Stop when estimated API cost exceeds this USD amount (default: no limit)
  e.g., `--budget 5.00` stops after $5 of estimated spend
- `--phase-timeout SECS`: Timeout per claude invocation in seconds (default: 1800 = 30 min)
  e.g., `--phase-timeout 3600` for 1-hour timeout per phase
- `--dry-run`: Preview what would happen

If no arguments provided, ask the user what they want to accomplish.

### 2. Initialize `.autopilot/` state directory

Create `.autopilot/` in the project root with:

**`.autopilot/mission.json`**:
```json
{
  "id": "<uuid>",
  "mission": "<user's mission text>",
  "mode": "mission|improve|execute|research",
  "scope": ["src/", "lib/"] or null,
  "constraints": {
    "maxHours": 8,
    "maxIterations": 50,
    "maxParallel": 3,
    "noDestructive": true,
    "requireTests": true
  },
  "startedAt": "<ISO timestamp>",
  "status": "active"
}
```

**`.autopilot/progress.json`**:
```json
{
  "iteration": 0,
  "tasks": [],
  "completed": [],
  "skipped": [],
  "errors": [],
  "commits": [],
  "learnings": [],
  "totalTokensEstimate": 0
}
```

**`.autopilot/handoff.md`**: Empty initially — populated after first iteration.

**`.autopilot/log.md`**: Initialized with mission header.

### 3. Run initial analysis (in-session)

Before starting the loop, do a quick codebase scan:

1. Read the project's CLAUDE.md, README, package.json (or equivalent) to understand the stack
2. Run `git log --oneline -20` to understand recent activity
3. Based on the mode:
   - **mission**: Decompose the mission into 5-15 concrete tasks, write to progress.json
   - **improve**: Run a codebase health scan (test coverage, lint issues, TODOs, security, performance), prioritize findings into tasks
   - **execute**: Delegate to GSD agents — uses actual `/gsd:discuss-phase`, `/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:verify-work` commands. Reads `.planning/ROADMAP.md` for phase dependencies, dispatches phases in dependency order with stuck detection. Requires `.planning/` directory (run `/gsd:new-project` first).
   - **research**: Create research subtopics as tasks
   - **evolve**: Do NOT decompose into tasks. Just initialize state files and start the loop. The strategist agent inside the loop generates milestones autonomously. Write an empty `tasks: []` to progress.json. Initialize `.autopilot/milestones.json` with empty milestones array.
   - **build-saas**: Initialize state files, set mode to `build-saas` in mission.json. Do NOT decompose into tasks — the script runs phased: market research → scaffold → core features (GSD) → marketing → polish → transitions to evolve. Mission text becomes the product description.
   - **marketing**: Initialize state files, set mode to `marketing` in mission.json. The script generates content iteratively (blog posts, social, pSEO pages) until hours/max-iterations reached.
4. Write the task list to `.autopilot/progress.json`
5. Write initial handoff notes to `.autopilot/handoff.md`

### 4. Start the autonomous loop

For modes other than `evolve`:
```bash
nohup bash "${CLAUDE_PLUGIN_ROOT}/scripts/autopilot.sh" \
  --project-dir "$(pwd)" \
  --max-iterations <N> \
  --hours <N> \
  --parallel <N> \
  > .autopilot/loop.log 2>&1 &
```

For `evolve` mode, also pass `--milestones` and `--focus` if provided:
```bash
nohup bash "${CLAUDE_PLUGIN_ROOT}/scripts/autopilot.sh" \
  --project-dir "$(pwd)" \
  --max-iterations <N> \
  --hours <N> \
  --milestones <N_or_omit> \
  --focus "<focus_or_omit>" \
  --budget "<budget_or_omit>" \
  --phase-timeout <timeout_or_1800> \
  > .autopilot/loop.log 2>&1 &
```

For `build-saas` mode:
```bash
nohup bash "${CLAUDE_PLUGIN_ROOT}/scripts/autopilot.sh" \
  --project-dir "$(pwd)" \
  --hours <N> \
  --budget "<budget_or_omit>" \
  --phase-timeout <timeout_or_1800> \
  > .autopilot/loop.log 2>&1 &
```

For `marketing` mode:
```bash
nohup bash "${CLAUDE_PLUGIN_ROOT}/scripts/autopilot.sh" \
  --project-dir "$(pwd)" \
  --max-iterations <N> \
  --hours <N> \
  --budget "<budget_or_omit>" \
  > .autopilot/loop.log 2>&1 &
```

### 5. Report to user

Output:
- Mission ID and mode
- Number of tasks planned
- Estimated completion scope
- PID of the background process
- How to check status: `/autopilot-status`
- How to stop: `/autopilot-stop`
- Log location: `.autopilot/loop.log`
- Budget limit (if `--budget` was set) and phase timeout
- Cost tracking: `.autopilot/costs.json` (updated after each iteration)

Add `.autopilot/` to `.gitignore` if not already there.

## Examples

```
/autopilot "Add dark mode support" --mode mission --hours 4
/autopilot --mode improve --hours 6 --focus "testing,security"
/autopilot --mode build-saas "AI-powered recipe generator for meal prep" --budget 50 --hours 12
/autopilot --mode marketing --hours 4 --budget 20
/autopilot --mode evolve --hours 24 --budget 100 --phase-timeout 2400
```
