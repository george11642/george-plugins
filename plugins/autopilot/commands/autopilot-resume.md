---
name: autopilot-resume
description: Resume a stopped autopilot session from its handoff state.
---

# /autopilot-resume

Resume a previously stopped or interrupted autopilot session.

## What to do

1. Verify `.autopilot/` exists with `mission.json` and `progress.json`.

2. Read current state:
   - How many tasks remain
   - What the last handoff notes say
   - Any errors from the previous run

3. Clean up stale state:
   - Remove `.autopilot/STOP` signal file if present
   - Update `mission.json` status back to "active"
   - Increment iteration counter

4. Optionally adjust parameters:
   - `--hours N`: Set new time limit
   - `--max-iterations N`: Set new iteration limit
   - `--skip-failed`: Mark previously failed tasks as skipped

5. Restart the loop:
   ```bash
   nohup bash "${CLAUDE_PLUGIN_ROOT}/scripts/autopilot.sh" \
     --project-dir "$(pwd)" \
     --resume \
     > .autopilot/loop.log 2>&1 &
   ```

6. Report resumed state to user.
