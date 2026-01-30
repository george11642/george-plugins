---
name: ralph-run
description: Start Ralph's autonomous content creation loop. Runs in background.
---

# /ralph-run

Start the Ralph Marketer autonomous content creation loop.

## What to do

1. Verify `.ralph/config.json` exists. If not, tell the user to run `/ralph-init` first.

2. Verify `scripts/ralph/prd.json` exists. If not, tell the user to run `/ralph-init` first.

3. Parse optional arguments:
   - `--max-iterations N` (default: 20)
   - `--dry-run` (show what would happen without executing)

4. Start the bash loop in background:
   ```
   nohup bash $PLUGIN_DIR/scripts/ralph-loop.sh [max_iterations] > .ralph/loop.log 2>&1 &
   ```

5. Report to the user:
   - "Ralph is now running in the background"
   - PID of the process
   - How to check status: `/ralph-status`
   - How to cancel: `/ralph-cancel`
   - Log location: `.ralph/loop.log`
