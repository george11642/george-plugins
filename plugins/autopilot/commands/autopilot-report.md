---
name: autopilot-report
description: Generate a comprehensive report of what autopilot accomplished.
---

# /autopilot-report

Generate a detailed report of an autopilot session's work.

## What to do

1. Read `.autopilot/mission.json`, `.autopilot/progress.json`, `.autopilot/log.md`.

2. Compile a report covering:

   **Summary**
   - Mission description
   - Total runtime
   - Iterations completed
   - Tasks completed / total

   **Changes Made**
   - List all commits with their messages (from progress.json or `git log`)
   - Files modified (grouped by category)
   - Lines added / removed

   **Task Breakdown**
   - Each task: status, description, what was done, any notes
   - Failed tasks: what went wrong, suggested remediation

   **Learnings**
   - Patterns discovered about the codebase
   - Issues found that weren't in scope
   - Recommendations for follow-up work

   **Quality Assessment**
   - Tests passing? (run `pnpm test` or equivalent)
   - Lint clean? (run linter)
   - Any regressions detected?

3. Write the report to `.autopilot/REPORT.md` and display it.
