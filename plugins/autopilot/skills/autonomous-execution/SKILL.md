---
name: autonomous-execution
description: "Auto-triggers when running inside an autopilot loop iteration. Provides the core methodology for autonomous task execution: orient from file state, implement one task, verify, commit, update state. Activates on: autopilot iteration, autonomous mode, overnight coding, unattended execution."
version: 1.0.0
---

# Autonomous Execution Methodology

You are running inside the Autopilot autonomous loop. Each iteration you get a FRESH context window.
Your durable state lives in `.autopilot/` files, NOT in conversation memory.

## The Single-Task Iteration Pattern

Every iteration follows this exact sequence:

### 1. ORIENT (Read State)
```
Read .autopilot/mission.json    → What's the goal?
Read .autopilot/progress.json   → What's done? What's next?
Read .autopilot/handoff.md      → What did the last iteration learn?
Run: git log --oneline -5       → What was recently committed?
```

Pick the FIRST task with `"status": "pending"` (lowest ID).

### 2. RESEARCH (If Needed)
- Spawn a researcher subagent for unfamiliar code/APIs
- Keep research bounded to what THIS task needs
- Skip if the task is straightforward

### 3. IMPLEMENT (One Task)
- Spawn an implementer subagent with the task + research context
- The implementer edits code, runs tests, self-reviews
- If the task needs multiple files, that's fine — but it's still ONE logical change

### 4. VERIFY (Fresh Eyes)
- For non-trivial changes, spawn a verifier subagent
- Verifier reads the git diff and scores the change
- If REJECT: fix issues (max 2 retries), then mark as error
- Skip verification for trivial changes (typos, comment updates)

### 5. COMMIT
- Stage only changed files (never `git add .`)
- Write a descriptive commit message
- Push if the project's CLAUDE.md says to

### 6. UPDATE STATE
Update `.autopilot/progress.json`:
- Current task → `"status": "completed"` (or `"error"`)
- Increment `"iteration"` counter
- Add commit hash to `"commits"` array
- Add lessons learned to `"learnings"` array

Update `.autopilot/handoff.md` with:
- What you just did
- What the next iteration should know
- Files you touched
- Any blockers or surprises

### 7. SIGNAL
Output: `AUTOPILOT_STATUS: ITERATION_COMPLETE`

## Anti-Patterns to Avoid

- **Multi-tasking**: Doing 3 tasks in one iteration. You'll rush and make mistakes.
- **Context hoarding**: Reading 50 files "just in case." Read what you need.
- **Skipping commits**: If it's not committed, it doesn't exist for the next iteration.
- **Forgetting handoff**: The next iteration starts from zero — handoff.md is its lifeline.
- **Over-engineering**: The simplest change that satisfies the task is the best change.
- **Infinite retries**: 2 attempts max, then mark as error and move on.

## Subagent Strategy

| Need | Agent | Model |
|------|-------|-------|
| Understand code/APIs | researcher | haiku (quick) or sonnet (deep) |
| Decompose mission | planner | sonnet |
| Write/edit code | implementer | sonnet |
| Review changes | verifier | sonnet |
| Analyze codebase health | improver | sonnet |

Spawn subagents via the Task tool. They run in isolated contexts and return results.
