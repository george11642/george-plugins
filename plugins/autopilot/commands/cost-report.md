---
name: cost-report
description: Show cost tracking report for autopilot runs
argument: "[path-to-costs.json]"
---

# Cost Report

Displays a detailed cost tracking report for the current or specified autopilot run.

## Usage

```
/autopilot:cost-report
/autopilot:cost-report .autopilot/costs.json
```

## What This Does

Shows:
- Total iterations run
- Total input/output tokens consumed
- Estimated cost in USD
- Average cost per iteration
- Last 5 iterations with individual costs
- Cost by model (Sonnet, Opus, Haiku breakdown)

## Implementation

<execution_context>
Determine the cost file path:
- If argument provided, use that
- Otherwise, check `.autopilot/costs.json` (autopilot costs)
- Also check `.planning/ralph-gsd-costs.json` (ralph-gsd costs)

Source the cost tracker and display reports:
```bash
source ~/.claude/scripts/cost-tracker.sh 2>/dev/null

if [[ -n "$ARGUMENTS" ]]; then
    cost_report "$ARGUMENTS"
elif [[ -f ".autopilot/costs.json" ]]; then
    echo "=== Autopilot Costs ==="
    cost_report ".autopilot/costs.json"
fi

if [[ -f ".planning/ralph-gsd-costs.json" ]]; then
    echo ""
    echo "=== Ralph-GSD Costs ==="
    cost_report ".planning/ralph-gsd-costs.json"
fi
```

If no cost files found, inform the user that no autopilot runs have been tracked yet.
</execution_context>
