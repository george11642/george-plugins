---
name: monitoring-sentry
description: "Use when checking Sentry errors, investigating production issues, or triaging error spikes. Triggers on Sentry, Sentry error, Sentry issue, check Sentry, production error, error spike, crash, Sentry Seer, search_issues, get_issue_details, analyze_issue, Sentry MCP, P0, triage, error rate, unresolved issues, Sentry project."
---

# Monitoring Sentry

Check project CLAUDE.md for Sentry org and project names.

## MCP Tools (via ToolSearch)
| Task | Tool |
|------|------|
| Search issues | `mcp__plugin_sentry_sentry__search_issues` |
| Get issue details | `mcp__plugin_sentry_sentry__get_issue_details` |
| Search events | `mcp__plugin_sentry_sentry__search_events` |
| AI analysis | `mcp__plugin_sentry_sentry__analyze_issue_with_seer` |

## Workflow
1. Search for recent issues: `search_issues` with project filter
2. Get details on critical issues: `get_issue_details`
3. Analyze root cause: `analyze_issue_with_seer`
4. Fix the code → commit → deploy
5. Verify issue resolves in Sentry

## Triage Priority
- P0: Crash affecting >10% users → fix immediately
- P1: Error spike (>5x baseline) → fix within session
- P2: Recurring error → fix when convenient
- P3: Edge case → DEFERRED.md
