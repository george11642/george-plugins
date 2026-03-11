---
name: testing-quality
description: "Use when running tests, writing test cases, checking coverage, or doing type-checks. Triggers on test, unit test, vitest, Playwright, E2E test, pytest, type-check, tsc --noEmit, test coverage, regression test, test suite, pnpm test, npx vitest, npx playwright test, test file, .test.ts, .spec.ts, describe, it, expect, mock."
---

# Testing Quality

## Commands
| Task | Command |
|------|---------|
| All unit tests | `npm test` / `pnpm test` |
| Single test file | `npx vitest path/to/test` |
| E2E tests | `npx playwright test` |
| Type check | `npx tsc --noEmit` or `npm run type-check` |
| Python tests | `pytest` |
| Coverage | `npx vitest --coverage` |

## Test Conventions
- Unit tests: `*.test.ts` co-located with source
- E2E tests: `e2e/*.spec.ts` (check project CLAUDE.md for exact path)
- E2E auth state and test users: check project CLAUDE.md

## When to Test
- After ANY code change: run unit tests
- After TypeScript changes: run type-check
- After Convex schema changes: `npx convex dev --once`
- After UI changes: browser screenshot verification
- New features MUST include unit tests
- Bug fixes MUST include regression tests

## Test Patterns
```typescript
// Vitest
import { describe, it, expect } from 'vitest';
describe('feature', () => {
  it('should work', () => { expect(true).toBe(true); });
});
```
