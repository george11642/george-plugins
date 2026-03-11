---
name: db-convex
description: "Use when writing Convex schema, queries, mutations, actions, or workflows. Triggers on Convex schema, defineTable, Convex query, Convex mutation, Convex action, httpAction, searchIndex, Convex index, identity.subject, use node, ConvexError, Convex workflow, v.string, v.object, Convex auth, Convex function, reactive query, Convex pagination, schema.ts."
---

# DB Convex

## Schema Pattern
```typescript
// schema.ts (check project CLAUDE.md for exact path)
defineTable({
  field: v.string(),
  optional: v.optional(v.string()),
  nested: v.object({ key: v.string() }),
})
  .index("by_field", ["field"])
  .searchIndex("search_field", { searchField: "field" })
```

## Function Types
| Type | Use Case | Runtime |
|------|----------|---------|
| `query` | Read data, reactive | V8 (no Node APIs) |
| `mutation` | Write data, transactional | V8 |
| `action` | External APIs, side effects | Node.js (`"use node"`) |
| `httpAction` | Webhook endpoints | Node.js |

## Key Patterns
- Auth: `identity.subject === clerkUserId` (NOT `tokenIdentifier.includes()`)
- Stripe SDK needs `"use node"` — split into separate files
- Check project CLAUDE.md for workflow, HTTP webhook, and cron file locations

## Anti-Patterns
- `instanceof ConvexError` (may fail in monorepos) -- use `"data" in err` (duck-type check)
- ConvexError data in actions (doesn't propagate to client) -- use client-side pre-flight checks for action errors
