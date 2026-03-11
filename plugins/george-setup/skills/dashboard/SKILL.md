---
description: "Launch or check the Claude Code monitoring dashboard. Use when: open dashboard, show dashboard, agent dashboard, monitoring, check agent activity, session stats, telemetry viewer."
---

# Dashboard Skill

Launch or check the agent activity dashboard.

## Actions

### Start Dashboard
```bash
bash ~/.claude/dashboard/start.sh
```
Then report: "Dashboard running at http://localhost:7860"

### Check Status
```bash
# Check if already running
lsof -ti :7860 >/dev/null 2>&1 && echo "Dashboard is running (PID: $(cat ~/.claude/dashboard/.pid 2>/dev/null || lsof -ti :7860))" || echo "Dashboard is not running"
```

### Stop Dashboard
```bash
kill $(cat ~/.claude/dashboard/.pid 2>/dev/null) 2>/dev/null || kill $(lsof -ti :7860) 2>/dev/null
echo "Dashboard stopped"
```

### Quick Stats (no server needed)
```bash
python3 -c "
import json; from pathlib import Path
b = json.loads((Path.home()/'.claude/behavior.json').read_text())
bg = json.loads((Path.home()/'.claude/budget.json').read_text())
print(f'Mode: {b.get(\"autonomy\",\"?\")} | Domain: {b.get(\"active_domain\",\"none\")} | Tools: {b.get(\"tool_call_count\",0)}/{bg.get(\"hard_limit\",200)}')
"
```
