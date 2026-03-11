---
name: deploy-convex
description: "Use when deploying Convex, pushing schema, running Convex CLI commands, or managing dev/prod Convex environments. Triggers on npx convex dev, npx convex deploy, convex dev --once, convex deploy -y, push schema, Convex deploy, Convex CLI, convex run, convex import, convex export, convex dashboard, _generated gitignore, Convex prod, Convex dev deployment."
---

# Deploy Convex

Check project CLAUDE.md for dev/prod deployment names and schema location.

## Commands
| Task | Command |
|------|---------|
| Push to dev | `npx convex dev --once` |
| Deploy to prod | `npx convex deploy -y` |
| Run function | `npx convex run 'module:function' '{"key": "val"}'` |
| View dashboard | `npx convex dashboard` |
| Import data | `npx convex import --table name file.json` |
| Export data | `npx convex export` |

## Gotchas
- In monorepos, run from the Convex package directory or repo root as appropriate
- Positional args: `npx convex run 'fn:name' '{"key": "val"}'` (no `--args` flag)
- `_generated/` is gitignored — never `git add` it
- `@convex-dev/workflow` caches step results including failures — new job needed after code fix
- ConvexError `instanceof` may fail in monorepos — use `"data" in err` duck-type

## Auth Pattern
```typescript
// In Next.js API routes, pass Clerk token:
const { getToken } = await auth();
const token = await getToken({ template: "convex" }) ?? undefined;
await fetchMutation(api.some.mutation, args, { token });
```
