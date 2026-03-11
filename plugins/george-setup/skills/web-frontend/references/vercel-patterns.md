# Vercel Performance Patterns

Consolidated from: vercel-react-best-practices (57 rules), vercel-composition-patterns

## Rule Categories by Priority

| Priority | Category | Impact |
|----------|----------|--------|
| 1 | Eliminating Waterfalls | CRITICAL |
| 2 | Bundle Size Optimization | CRITICAL |
| 3 | Server-Side Performance | HIGH |
| 4 | Client-Side Data Fetching | MEDIUM-HIGH |
| 5 | Re-render Optimization | MEDIUM |
| 6 | Rendering Performance | MEDIUM |
| 7 | JavaScript Performance | LOW-MEDIUM |

## 1. Eliminating Waterfalls (CRITICAL)

### Defer Await
```tsx
// BAD: blocks even when data isn't used
async function Page() {
  const data = await fetchData() // blocks
  if (someCondition) return <Fallback />
  return <Component data={data} />
}

// GOOD: only await when needed
async function Page() {
  if (someCondition) return <Fallback />
  const data = await fetchData()
  return <Component data={data} />
}
```

### Parallel Fetching
```tsx
// BAD: sequential
const users = await fetchUsers()
const posts = await fetchPosts()

// GOOD: parallel
const [users, posts] = await Promise.all([fetchUsers(), fetchPosts()])
```

### Suspense Streaming
```tsx
// Stream slow components without blocking fast ones
<Suspense fallback={<Skeleton />}>
  <SlowDataComponent />
</Suspense>
```

## 2. Bundle Size (CRITICAL)

- **Import directly**: `import { Button } from "./Button"` not `from "./components"`
- **Dynamic import**: `const Chart = dynamic(() => import("./Chart"), { ssr: false })`
- **Defer third-party**: Load analytics after hydration via `useEffect`
- **Preload on hover**: `onMouseEnter={() => import("./HeavyComponent")}`

## 3. Server-Side (HIGH)

- `React.cache()` for per-request dedup across components
- LRU cache for cross-request caching (hot data)
- Minimize data in RSC props (don't serialize unused fields)
- `after()` for non-blocking operations (analytics, logs)
- Authenticate server actions like API routes

## 4. Client-Side Data (MEDIUM-HIGH)

- SWR for automatic request deduplication
- Deduplicate global event listeners (resize, scroll)
- Use `{ passive: true }` for scroll/touch listeners
- Version localStorage schemas, minimize stored data

## 5. Re-render Optimization (MEDIUM)

| Pattern | Rule |
|---------|------|
| Stable callbacks | `setCount(c => c + 1)` not `setCount(count + 1)` |
| Ref for transient | `useRef` for scroll pos, hover, frequent values |
| Derive during render | Compute in render, not useEffect |
| Lazy state init | `useState(() => expensive())` |
| Primitive deps | `useEffect(() => {}, [user.id])` not `[user]` |
| Skip memo for cheap | Don't memo simple string/number comparisons |

## 6. Rendering (MEDIUM)

- `content-visibility: auto` for long off-screen lists
- Animate `transform`/`opacity` not `width`/`height`
- Hoist static JSX outside component function
- Use ternary `{x ? <A/> : <B/>}` not `{x && <A/>}` (avoids falsy render)
- `useTransition` for loading states over boolean flags

## 7. JavaScript (LOW-MEDIUM)

- `Set`/`Map` for O(1) lookups instead of Array.find/includes
- Cache function results in module-level Map
- Combine multiple .filter().map() into single loop
- Check array length before expensive comparisons
- Hoist RegExp creation outside loops

## Full Rule Reference

For detailed code examples of each rule, see the Layer 3 skill:
`~/.claude/skills/vercel-react-best-practices/rules/`
