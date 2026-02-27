---
name: autopilot
description: "Start autonomous coding loop. Modes: mission (default), improve, execute, research."
argument-hint: '"mission description" [--mode mission|improve|execute|research] [--hours N] [--max-iterations N] [--parallel N] [--dry-run]'
---

# /autopilot — Autonomous Overnight Coding Agent

Start a fully autonomous coding loop that runs for hours without human intervention.

## What to do

### 1. Parse arguments

Extract from `$ARGUMENTS`:
- **Mission text**: The quoted string (required for mission/research modes)
- `--mode`: `mission` (default) | `improve` | `execute` | `research`
- `--hours`: Max runtime in hours (default: 8)
- `--max-iterations`: Safety limit per session (default: 50)
- `--parallel`: Max parallel subagents per iteration (default: 3)
- `--plan`: Path to existing plan file (required for execute mode)
- `--scope`: Limit to specific directories (comma-separated)
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
   - **execute**: Parse the plan file into tasks
   - **research**: Create research subtopics as tasks
4. Write the task list to `.autopilot/progress.json`
5. Write initial handoff notes to `.autopilot/handoff.md`

### 4. Start the autonomous loop

```bash
nohup bash "${CLAUDE_PLUGIN_ROOT}/scripts/autopilot.sh" \
  --project-dir "$(pwd)" \
  --max-iterations <N> \
  --hours <N> \
  --parallel <N> \
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
