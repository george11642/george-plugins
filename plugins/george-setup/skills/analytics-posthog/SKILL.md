---
name: analytics-posthog
description: "Use when setting up PostHog analytics, feature flags, experiments, or querying PostHog data. Triggers on PostHog, PostHog event, PostHog feature flag, PostHog experiment, A/B test PostHog, HogQL, PostHog funnel, PostHog dashboard, PostHog LLM cost, posthog.capture, isFeatureEnabled, PostHog MCP, PostHog survey, PostHog error tracking."
---

# Analytics PostHog

## MCP Tools (via ToolSearch — use PostHog skills for structured access)
| Task | Skill/Tool |
|------|-----------|
| Query analytics | `/posthog:query` or `/posthog:insights` |
| Feature flags | `/posthog:flags` |
| Experiments | `/posthog:experiments` |
| Error tracking | `/posthog:errors` |
| Search entities | `/posthog:search` |
| Dashboards | `/posthog:dashboards` |

## Event Tracking Pattern
```typescript
posthog.capture('event_name', {
  property: 'value',
  $set: { user_property: 'value' }
});
```

## Feature Flag Pattern
```typescript
if (posthog.isFeatureEnabled('flag-name')) {
  // new behavior
}
```

## Best Practices
- Use HogQL for complex queries
- Group events by user for funnel analysis
- A/B test with experiments before full rollout
- Track LLM costs with `/posthog:llm-analytics`
