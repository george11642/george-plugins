---
name: ralph-gsd
description: Use when the user asks to start, run, or resume ralph-gsd (the autonomous milestone execution loop). Invokes the monitor skill then launches ralph-gsd in the background.
---

# ralph-gsd: Run

Starts the autonomous ralph-gsd milestone execution loop and sets up the 2-hour background monitor.

## Steps (always in this order)

### 1. Invoke the monitor skill FIRST

Before launching ralph-gsd, invoke the monitor skill to set up the 2-hour watchdog:

```
Skill("ralph-gsd-monitor")
```

This sets up a CronCreate job — no further action needed.

### 2. Launch ralph-gsd

Spawn an agent to start ralph-gsd in the background:

```bash
cd /home/george/projects/active/businessagent && nohup bash /home/george/.claude/scripts/ralph-gsd.sh \
  --project-dir /home/george/projects/active/businessagent \
  --skip-discuss \
  --max-parallel 4 \
  >> .planning/ralph-gsd.log 2>&1 &
```

Use `--resume` flag if the user asks to resume after a stop.

### 3. Confirm

Return the PID and confirm both the ralph-gsd process and the monitor cron are active.

## Key Facts

- Project: /home/george/projects/active/businessagent
- Log: `.planning/ralph-gsd.log`
- Monitor: every 2 hours at :13 (set up via ralph-gsd-monitor skill)
- Restart cmd same as launch cmd above, add `--resume` to skip already-verified phases
