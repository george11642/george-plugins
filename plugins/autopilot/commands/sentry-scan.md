---
name: sentry-scan
description: Scan Sentry for production issues and auto-fix them
argument: "[--max-issues N] [--severity critical|high|medium|low]"
---

# Sentry Auto-Fix Scanner

Scans Sentry for unresolved production issues, analyzes root causes, and implements fixes.

## Usage

```
/autopilot:sentry-scan
/autopilot:sentry-scan --max-issues 5 --severity critical
```

## What This Does

1. Connects to Sentry via MCP and retrieves unresolved issues
2. Prioritizes by user impact (frequency x affected users)
3. For each issue:
   - Analyzes stack trace and event data
   - Uses Sentry Seer for AI-powered root cause analysis
   - Implements a targeted fix
   - Runs tests to verify the fix
   - Creates a git commit
4. Outputs a summary of fixed, deferred, and skipped issues

## Arguments

- `--max-issues N` — Maximum issues to process (default: 10)
- `--severity LEVEL` — Minimum severity to process: critical, high, medium, low (default: high)

## Implementation

<execution_context>
Parse arguments from `$ARGUMENTS`:
- Extract `--max-issues` value (default: 10)
- Extract `--severity` value (default: high)

Run the sentry scan script:
```bash
bash ~/.claude/scripts/sentry-scan.sh "$(pwd)" "$MAX_ISSUES" "$SEVERITY"
```

After completion, read and display the results from `.autopilot/sentry-scan-results.json`.

If the script is not found, inform the user they need the infrastructure scripts installed.
</execution_context>
