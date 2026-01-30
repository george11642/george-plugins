---
name: ralph-cancel
description: Stop Ralph's running content loop.
---

# /ralph-cancel

Stop the Ralph Marketer loop if it's running.

## What to do

1. Check if `.ralph/loop.lock` exists
   - If not: "No Ralph loop is currently running."
   - If yes: Read the PID from the lock file

2. Check if the PID is actually running (`kill -0 PID`)
   - If running: Kill it (`kill PID`), remove the lock file
   - If not running: Remove stale lock file

3. Update `.ralph/state.json` status to "cancelled"

4. Report:
   - "Ralph loop stopped (was at iteration X)"
   - "Progress saved in scripts/ralph/progress.txt"
   - "Resume with /ralph-run"
