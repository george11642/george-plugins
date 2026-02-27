---
name: autopilot
description: "Start autonomous coding loop. Modes: mission (default), improve, execute, research, evolve."
argument-hint: '"mission description" [--mode mission|improve|execute|research|evolve] [--hours N] [--max-iterations N] [--parallel N] [--milestones N] [--focus "areas"] [--dry-run]'
---

# /autopilot — Autonomous Overnight Coding Agent

Start a fully autonomous coding loop that runs for hours without human intervention.

## What to do

### 1. Parse arguments

Extract from `$ARGUMENTS`:
- **Mission text**: The quoted string (required for mission/research modes; optional for evolve/improve)
- `--mode`: `mission` (default) | `improve` | `execute` | `research` | `evolve`
- `--hours`: Max runtime in hours (default: 8)
- `--max-iterations`: Safety limit per session (default: 50)
- `--parallel`: Max parallel subagents per iteration (default: 3)
- `--plan`: Path to existing plan file (for execute mode, defaults to .planning/ROADMAP.md)
- `--scope`: Limit to specific directories (comma-separated)
- `--skip-discuss`: In execute mode, skip GSD discuss phases (go straight to plan)
- `--milestones N`: In evolve mode, max milestones to complete (default: unlimited)
- `--focus AREAS`: In evolve mode, comma-separated focus areas for the strategist
  e.g., `"testing,security"` or `"performance,reliability,observability"`
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

Add `.autopilot/` to `.gitignore` if not already there.
