# Component Patterns: React, Vue, Svelte

## React Patterns

### Component Architecture
- **Composition over inheritance**: use children prop and render slots
- **Container/Presentational split**: logic in hooks, UI in components
- **Compound components**: related components sharing implicit state (Tabs, Accordion)

### Performance
- `React.memo()` for expensive pure components
- `useMemo` / `useCallback` for referential stability
- Lazy load routes: `React.lazy()` + `<Suspense>`
- Virtualize long lists: `react-window` or `@tanstack/virtual`
- Avoid prop drilling: use composition or context (sparingly)

### State Management
- Local state: `useState` for component-scoped
- Derived state: compute in render, don't sync with `useEffect`
- Server state: TanStack Query / SWR (cache, dedup, background refetch)
- Global state: Zustand (simple), Jotai (atomic), Redux Toolkit (complex)

### Form Patterns
- React Hook Form for complex forms (validation, performance)
- Controlled inputs for simple forms (< 5 fields)
- Zod for schema validation with TypeScript inference
- Inline validation: validate on blur, show error below field

### shadcn/ui Integration
- Install via CLI: `npx shadcn@latest add [component]`
- Components are copied to `src/components/ui/` — fully customizable
- Theming: CSS variables in `globals.css` for consistent design tokens
- Use `cn()` utility for conditional class merging
- Key components: Button, Dialog, Sheet, Dropdown, Command, DataTable

### Next.js Specifics
- Use Server Components by default, `'use client'` only when needed
- `next/image` for optimized images with blur placeholder
- Route groups `(marketing)` for layout organization
- Parallel routes and intercepting routes for modals
- Metadata API for SEO: `export const metadata = {...}`

## Vue Patterns

### Composition API
```vue
<script setup>
import { ref, computed, watch, onMounted } from 'vue'
const count = ref(0)
const doubled = computed(() => count.value * 2)
</script>
```

### Key Patterns
- `<script setup>` for concise single-file components
- Composables (`use*` functions) for reusable logic
- `defineProps` / `defineEmits` for type-safe component API
- Pinia for state management (replaces Vuex)
- `v-model` with custom components via `modelValue` prop
- Teleport for portals (modals, tooltips)

## Svelte Patterns

### Svelte 5 (Runes)
```svelte
<script>
let count = $state(0)
let doubled = $derived(count * 2)
$effect(() => { console.log(count) })
</script>
```

### Key Patterns
- Runes (`$state`, `$derived`, `$effect`) replace stores for local state
- `{#snippet}` for reusable template fragments
- Component props via `$props()`
- SvelteKit: file-based routing, `+page.svelte` / `+layout.svelte`
- Form actions for progressive enhancement

## Cross-Framework Patterns

### Accessible Component Checklist
| Component | Required ARIA | Keyboard |
|---|---|---|
| Modal/Dialog | `role="dialog"`, `aria-modal`, `aria-labelledby` | Escape to close, focus trap |
| Dropdown | `aria-expanded`, `aria-haspopup`, `role="menu"` | Arrow keys, Enter, Escape |
| Tabs | `role="tablist/tab/tabpanel"`, `aria-selected` | Arrow keys, Home/End |
| Toast | `role="alert"`, `aria-live="polite"` | Auto-dismiss, close button |
| Accordion | `aria-expanded`, `aria-controls` | Enter/Space to toggle |
| Tooltip | `role="tooltip"`, `aria-describedby` | Focus trigger to show |

### Responsive Component Patterns
- **Mobile-first**: design for smallest screen, enhance upward
- **Drawer vs Modal**: drawers on mobile, modals on desktop
- **Responsive tables**: horizontal scroll or card layout on mobile
- **Navigation**: hamburger menu on mobile, full nav on desktop
- **Touch vs hover**: tap to reveal on mobile, hover on desktop

### Loading States
- Skeleton screens matching content layout (not generic spinners)
- Optimistic updates for user-initiated actions
- Progress bars for deterministic operations
- Infinite scroll with intersection observer
