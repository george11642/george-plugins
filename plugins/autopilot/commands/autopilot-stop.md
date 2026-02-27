---
name: autopilot-stop
description: Gracefully stop the autonomous loop.
---

# /autopilot-stop

Gracefully stop a running autopilot session.

## What to do

1. Check `.autopilot/loop.pid` exists and process is running.

2. Create `.autopilot/STOP` signal file (the loop script checks for this).

3. Wait up to 30 seconds for the current iteration to finish:
   ```bash
   touch .autopilot/STOP
   echo "Stop signal sent. Waiting for current iteration to finish..."
   ```

4. If user passes `--force`, kill the process directly:
   ```bash
   kill $(cat .autopilot/loop.pid) 2>/dev/null
   ```

5. Show final status using the same dashboard as `/autopilot-status`.

6. Update `mission.json` status to "stopped".
