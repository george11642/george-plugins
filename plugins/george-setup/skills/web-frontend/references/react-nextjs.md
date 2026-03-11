# React & Next.js Patterns

Consolidated from: js-ts-dev, vercel-react-best-practices, vercel-composition-patterns

## React Component Patterns

### Hooks Best Practices
- `useState` with lazy initializer for expensive defaults: `useState(() => computeExpensive())`
- `useRef` for transient values that don't trigger re-renders (scroll position, timers)
- `useMemo`/`useCallback` only when measurably needed — not by default
- `useTransition` for non-urgent state updates (search, filtering)
- Custom hooks: extract shared stateful logic, prefix with `use`, return tuple or object

### Component Architecture
- **Server Components** (default in App Router): No `"use client"`, can `await`, access DB directly
- **Client Components**: Add `"use client"` directive, for interactivity, hooks, browser APIs
- **Composition over inheritance**: Use children prop, render props, compound components
- Avoid boolean prop proliferation — use explicit variant components instead
- Compound components with shared context for complex UI (Tabs, Accordion, Dropdown)

### State Management
- **Local state**: `useState` for component-scoped state
- **Lifted state**: Move to nearest common ancestor for sibling access
- **Context**: For cross-tree state (theme, auth, locale). Split read/write contexts
- **URL state**: `useSearchParams` for shareable/bookmarkable state
- **Server state**: React Query / SWR for cache, dedup, background refetch

## Next.js App Router

### File Conventions
```
app/
  layout.tsx        # Shared UI wrapper (persists across navigations)
  page.tsx          # Unique route UI
  loading.tsx       # Suspense fallback
  error.tsx         # Error boundary (must be "use client")
  not-found.tsx     # 404 UI
  route.ts          # API route handler
  template.tsx      # Re-renders on navigation (vs layout persistence)
  proxy.ts          # Network proxy (replaces middleware.ts in Next.js 16)
```

### Data Fetching Patterns
- **Server Components**: `fetch()` directly in component, auto-deduped per request
- **React.cache()**: Per-request memoization for DB queries shared across components
- **Parallel fetching**: Restructure components to fetch independently, wrap in Suspense
- **`after()`**: Run non-blocking work after response (analytics, logging) — stable in Next.js 16

### Server Actions
```tsx
"use server"
async function createItem(formData: FormData) {
  // Validate input with Zod
  // Authenticate via cookies/session
  // Mutate DB
  revalidatePath("/items")
}
```
- Always authenticate server actions (they're public endpoints)
- Use `useActionState` for form state (pending, error, result)
- Call `revalidatePath`/`revalidateTag` after mutations

### Routing
- **Parallel routes**: `@modal/page.tsx` for modals, `@sidebar/page.tsx` for panels
- **Intercepting routes**: `(.)photo/[id]` for modal-on-click, full-page-on-direct-nav
- **Route groups**: `(marketing)/`, `(app)/` for shared layouts without URL segments
- **Dynamic segments**: `[id]`, `[...slug]`, `[[...slug]]` (optional catch-all)

## Performance Critical Rules

### Eliminating Waterfalls (CRITICAL)
1. **Defer await**: Move `await` into branches where actually used
2. **Parallel promises**: `Promise.all()` for independent operations
3. **Start early, await late**: Begin promises at route entry, await when needed
4. **Suspense boundaries**: Stream content with `<Suspense>` around slow components

### Bundle Size (CRITICAL)
1. **No barrel imports**: Import directly from `./Button` not `./components`
2. **Dynamic imports**: `next/dynamic` for heavy components (charts, editors)
3. **Defer third-party**: Load analytics/tracking after hydration
4. **Conditional loading**: Import modules only when feature flag is active
5. **Preload on hover**: `router.prefetch()` or dynamic import on hover/focus

### Re-render Optimization (MEDIUM)
- Don't subscribe to state only used in callbacks — use ref instead
- Hoist default non-primitive props outside component
- Use primitive dependencies in useEffect (id instead of object)
- Derive state during render, never in useEffect
- Functional setState for stable callbacks: `setCount(c => c + 1)`

## React 19 Changes
- `ref` is a regular prop — no `forwardRef` needed
- `use()` replaces `useContext()` and can unwrap promises
- `useFormStatus()` for pending state in forms
- `useOptimistic()` for optimistic UI updates
- `useActionState()` replaces deprecated `useFormState()` — includes `pending` state directly
- Server Components are the default in Next.js App Router
- React Compiler (stable in Next.js 16) — auto-memoization, no manual `useMemo`/`useCallback`

### React 19.2 Changes (shipped with Next.js 16)
- **View Transitions**: `<ViewTransition>` component for animating elements during navigation
- **`useEffectEvent`**: Extract non-reactive logic from effects without re-triggering them
- **`<Activity>`**: Render background activity (previously called `<Offscreen>`)

### useActionState Pattern (React 19 + Next.js 16)
```tsx
'use client'
import { useActionState } from 'react'
import { createUser } from '@/app/actions'

export function Signup() {
  const [state, formAction, pending] = useActionState(createUser, { message: '' })
  return (
    <form action={formAction}>
      <input type="email" name="email" required />
      <p aria-live="polite">{state?.message}</p>
      <button disabled={pending}>Sign up</button>
    </form>
  )
}
```

### Server Action with useActionState Validation
```tsx
'use server'
// First arg is previous state when used with useActionState
export async function createUser(prevState: any, formData: FormData) {
  const validated = schema.safeParse({ email: formData.get('email') })
  if (!validated.success) return { message: 'Invalid input' }
  // mutate DB, then revalidatePath
}
```

## Next.js 16 Features

### Turbopack (Default Bundler)
- Default for both dev and production builds — 5-10x faster Fast Refresh, 2-5x faster builds
- File System Caching stable: compiler artifacts stored on disk, faster restarts
- Custom Webpack configs ignored by default — use `--webpack` flag to opt out of Turbopack
- Migrate webpack config to Turbopack-compatible options or keep `--webpack`

### Cache Components (`use cache`)
- Opt-in caching via `"use cache"` directive at file, component, or function level
- Replaces implicit App Router caching — all dynamic code runs at request time by default
- Enable with `cacheComponents: true` in `next.config.ts` (replaces `experimental.dynamicIO`)
- Compiler auto-generates cache keys
```tsx
// Component-level caching
async function ProductList() {
  'use cache'
  const products = await db.product.findMany()
  return <List items={products} />
}
```

### Proxy (replaces Middleware)
- `middleware.ts` renamed to `proxy.ts`, exported function renamed to `proxy`
- Runs on Node.js runtime only — Edge runtime NOT supported in proxy
- Config renames: `skipMiddlewareUrlNormalize` → `skipProxyUrlNormalize`
- Codemod available: `npx @next/codemod@latest middleware-to-proxy .`
```ts
// proxy.ts
import { NextRequest, NextResponse } from 'next/server'
export default function proxy(request: NextRequest) {
  return NextResponse.redirect(new URL('/home', request.url))
}
```

### Async Request APIs (Breaking Change)
- `params`, `searchParams`, `cookies()`, `headers()`, `draftMode()` now return Promises
- Synchronous access fully removed (was deprecated in Next.js 15)
```tsx
// Next.js 16 — must await
export default async function Page(props: {
  params: Promise<{ slug: string }>
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>
}) {
  const params = await props.params
  const searchParams = await props.searchParams
}

const cookieStore = await cookies()
const headersList = await headers()
```

### Other Next.js 16 Changes
- **React Compiler**: Stable built-in support — auto-memoization with zero manual code
- **`after()`**: Stable API (was `unstable_after()`) for post-response work
- **AMP removed**: `amp: true` / `amp: 'hybrid'` no longer supported
- **next/image**: Lazy-loading automatic, `layout` prop removed, use CSS for `objectFit`/`objectPosition`
- **DevTools MCP**: Model Context Protocol integration for AI-assisted debugging
- **`next upgrade`**: New CLI command for automated version upgrades

## Anti-Patterns to Avoid
- Fetching in `useEffect` when server component would work
- Putting all state in global store (use local state first)
- `useEffect` for derived state (compute during render instead)
- Wrapping everything in `React.memo` (profile first)
- Barrel file re-exports that prevent tree-shaking
- Using synchronous `cookies()`/`headers()` (must await in Next.js 16)
- Using `middleware.ts` instead of `proxy.ts` (deprecated in Next.js 16)
