---
name: typescript-core
description: "Use for TypeScript/JavaScript LANGUAGE-LEVEL type system, compiler, build tooling, and package management — NOT for framework-specific work. Triggers on generics, conditional types, mapped types, template literal types, type guards, discriminated unions, utility types, type narrowing, infer keyword, satisfies, const assertions, recursive types, 'Type instantiation is excessively deep', advanced JS (Proxy, Reflect, Symbol, WeakMap, iterators, generators), build tools (Vite config, esbuild, Turbopack, Webpack, tree-shaking), tsconfig, strict mode, path aliases, incremental builds, ESLint flat config, typescript-eslint, Prettier, dependency injection (tsyringe, inversify), package managers (npm, pnpm, yarn workspaces, peer dependencies). NOT for React components or JSX (use web-frontend), NOT for REST/GraphQL API routes or JWT auth middleware (use backend-data), NOT for writing or running test files like .test.ts or Playwright (use testing-quality), NOT for security audits or vulnerability scanning (use security-deep). Even when a type-system question appears inside a test file context, this skill handles the TYPE question, not the test methodology."
---

# TypeScript Core

Layer 2 domain skill for TypeScript/JavaScript language-level patterns, type system, and build tooling. Not frontend or backend specific — pure language and tooling.

## Task Router

| Task Pattern | Reference | Layer 3 Skills |
|---|---|---|
| Generics, conditional types, mapped types, template literals | `references/advanced-types.md` | — |
| Type guards, discriminated unions, utility types, `satisfies` | `references/advanced-types.md` | — |
| ES6+, async/await, destructuring, modules, generators | `references/modern-js.md` | — |
| Proxy, Reflect, Symbol, WeakMap, private fields, iterators | `references/advanced-js-patterns.md` | — |
| Vite, esbuild, Webpack, Turbopack, HMR, tree-shaking | `references/build-tools.md` | — |
| tsconfig, path aliases, strict mode, incremental builds | `references/build-tools.md` | — |
| DI containers, tsyringe, inversify, composition root | `references/dependency-injection.md` | — |
| ESLint flat config, Prettier, lint-staged, husky | `references/build-tools.md` | — |

## When to Use

Activate for any task involving:
- TypeScript type system (generics, conditional, mapped, template literal types)
- Type guards and narrowing strategies
- Modern JavaScript patterns (async generators, Proxy, Symbol)
- Build tool configuration (Vite, esbuild, tsconfig)
- Dependency injection architecture
- Package management (npm, pnpm, yarn)
- Linting and formatting setup

## Layer 3 Skills (Atomic)

- **testing-quality** — TypeScript test methodology, vitest, jest configuration

## Quick Reference

### Type System Hierarchy
```
unknown (top type — accepts everything, must narrow to use)
  ├─ object, string, number, boolean, symbol, bigint
  ├─ any (escape hatch — avoid)
  └─ never (bottom type — impossible values, exhaustive checks)
```

### Common Type Patterns
```typescript
// Discriminated union
type Result<T> = { ok: true; value: T } | { ok: false; error: Error }

// Template literal
type EventName = `on${Capitalize<'click' | 'hover'>}` // "onClick" | "onHover"

// Conditional
type IsArray<T> = T extends any[] ? true : false

// Mapped with filtering
type ReadonlyPick<T, K extends keyof T> = { readonly [P in K]: T[P] }
```

### Best Practices
- `unknown` over `any` — forces narrowing
- `interface` for objects, `type` for unions/intersections
- `satisfies` for type checking without widening
- `const` assertions for literal types
- Strict mode: `strict: true` in tsconfig (enables all strict checks)
