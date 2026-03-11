---
name: web-frontend
description: Use for any browser-rendered UI work. Triggers on React components, hooks, state, props, JSX, Next.js pages, App Router, SSR, RSC, server actions, Tailwind CSS classes, responsive layout, dark mode, styling, CSS, accessibility, ARIA, keyboard navigation, focus management, UI design systems, color palettes, typography, component architecture, compound components, frontend performance, LCP, Lighthouse, re-renders, bundle size, Playwright browser tests, Testing Library, Remotion video compositions, captions, animations. Covers design patterns, hover states, forms, modals, navigation, grids, and any .tsx/.jsx file editing.
---

# Web Frontend

Layer 2 domain skill for all browser-side UI development. Routes to reference files and Layer 3 atomic skills by task type.

## Task Router

| Task Pattern | Reference | Layer 3 Skills |
|---|---|---|
| React component, hooks, state, props | `references/react-nextjs.md` | — |
| Next.js pages, App Router, SSR, RSC | `references/react-nextjs.md` | deploy-vercel |
| Styling, Tailwind, CSS, dark mode | `references/tailwind-patterns.md` | — |
| Accessibility, ARIA, keyboard nav, focus | `references/accessibility.md` | — |
| UI design system, UX guidelines, checklist | `references/ui-design-system.md` | — |
| UI style selection, glassmorphism, brutalism, etc. | `references/ui-design-styles.md` | — |
| Color palettes by product type | `references/ui-color-palettes.md` | — |
| Font pairings, Google Fonts, typography | `references/ui-font-pairings.md` | — |
| Chart types, data visualization | `references/ui-chart-types.md` | — |
| Landing pages, layout patterns, product-type mapping | `references/ui-layout-patterns.md` | — |
| Component architecture, composition, compound components | `references/component-architecture.md` | — |
| React/Next.js performance, re-renders, bundles, waterfalls | `references/vercel-patterns.md` | — |
| Frontend testing, Testing Library, Playwright, MSW | `references/frontend-testing.md` | testing-quality |
| Remotion video, animation, captions, sequencing | `references/remotion.md` | — |

## When to Use

Activate for any task involving:
- React/Next.js components, pages, or layouts
- Tailwind CSS, styling, responsive design
- UI/UX design decisions, color palettes, typography
- Accessibility audits or improvements
- Frontend performance optimization
- Component testing with Testing Library or Playwright
- Remotion video composition

## Layer 3 Skills (Atomic)

These tool-wrapper skills provide external integrations:

- **deploy-vercel** — Vercel deployment configuration and management
- **testing-quality** — Playwright browser automation, Testing Library, test methodology
- **auth-clerk** — Clerk authentication setup and protected routes

## Quick Decision Trees

### Styling Approach
```
Need design system from scratch? → references/ui-design-system.md
Existing design, need implementation? → references/tailwind-patterns.md
Performance issue with CSS? → references/vercel-patterns.md (rendering section)
```

### Testing Strategy
```
Unit test a component? → references/frontend-testing.md (Testing Library)
E2E browser test? → references/frontend-testing.md (Playwright)
Mock API calls? → references/frontend-testing.md (MSW)
Visual regression? → testing-quality skill
```
