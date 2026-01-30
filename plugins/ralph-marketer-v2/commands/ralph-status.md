---
name: ralph-status
description: Show Ralph's pipeline status, story completion, and recent activity.
---

# /ralph-status

Show the current state of Ralph's content pipeline.

## What to do

1. Check if `.ralph/state.json` exists. If not, say "Ralph hasn't been initialized. Run /ralph-init first."

2. Read and display:
   - **Loop status**: from `.ralph/state.json` (running/completed/error/max_iterations)
   - **Current iteration**: from state.json
   - **Lock file**: Check if `.ralph/loop.lock` exists (is loop running?)

3. Read `scripts/ralph/prd.json` and display:
   - Total stories count
   - Completed (passes: true) count
   - Pending count
   - Completion percentage with a progress bar

4. Read recent entries from `scripts/ralph/progress.txt` (last 10 lines)

5. Check `content/drafts/` and `content/published/` for file counts

6. If the SQLite DB exists at `data/ralph.db`, run `node $PLUGIN_DIR/scripts/src/db/status.js`

Format the output as a clean, readable status dashboard.
