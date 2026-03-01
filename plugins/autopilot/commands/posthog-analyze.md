---
name: posthog-analyze
description: Analyze PostHog metrics and generate improvement recommendations
argument: ""
---

# PostHog Analytics Analyzer

Analyzes product analytics to identify improvement opportunities, funnel drop-offs, and unused features.

## Usage

```
/autopilot:posthog-analyze
```

## What This Does

1. Connects to PostHog via MCP
2. Queries: page views, user retention, conversion funnels, feature usage, error rates
3. Identifies: drop-off points, underused features, error-prone pages
4. Generates prioritized recommendations (QUICK_WIN, MEDIUM_EFFORT, STRATEGIC)
5. Suggests A/B tests for top recommendations

## Implementation

<execution_context>
Run the PostHog analysis script:
```bash
bash ~/.claude/scripts/posthog-analyze.sh "$(pwd)"
```

After completion, read and display the analysis from `.autopilot/posthog-analysis.md`.

If the script is not found, inform the user they need the infrastructure scripts installed.
</execution_context>
