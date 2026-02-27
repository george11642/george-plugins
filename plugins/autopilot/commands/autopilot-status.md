---
name: autopilot-status
description: Check autonomous loop progress, completed tasks, and current state.
---

# /autopilot-status

Check the status of a running or completed autopilot session.

## What to do

1. Check if `.autopilot/` exists. If not, tell user no autopilot session found.

2. Read `.autopilot/mission.json` and `.autopilot/progress.json`.

3. Check if the loop process is still running:
   ```bash
   if [ -f .autopilot/loop.pid ]; then
     kill -0 $(cat .autopilot/loop.pid) 2>/dev/null && echo "RUNNING" || echo "STOPPED"
   fi
   ```

4. Display a concise dashboard:
   - **Mission**: The goal
   - **Mode**: mission/improve/execute/research
   - **Status**: Running / Stopped / Complete
   - **Progress**: X/Y tasks complete
   - **Current iteration**: N
   - **Runtime**: HH:MM since start
   - **Commits made**: N (list recent 5)
   - **Errors**: N (list if any)
   - **Skipped tasks**: N (list if any)
   - **Learnings**: Key insights the agent discovered

5. Show last 10 lines of `.autopilot/log.md` for recent activity.

6. If there are errors, suggest running `/autopilot-resume` to retry.
