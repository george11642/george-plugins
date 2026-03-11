# Tailwind CSS & Styling Patterns

Consolidated from: ui-ux-pro-max, vercel-react-best-practices

## Core Tailwind Principles

### Responsive Design
- Mobile-first: base styles = mobile, `sm:` = 640px, `md:` = 768px, `lg:` = 1024px, `xl:` = 1280px, `2xl:` = 1536px
- Test at: 375px (mobile), 768px (tablet), 1024px (laptop), 1440px (desktop)
- Never cause horizontal scroll on mobile
- Use `max-w-6xl` or `max-w-7xl` consistently — don't mix container widths

### Layout Utilities
```
flex items-center justify-between    # Horizontal layout
flex flex-col gap-4                  # Vertical stack with spacing
grid grid-cols-1 md:grid-cols-2     # Responsive grid
container mx-auto px-4              # Centered container
```

### Spacing System
- Use consistent scale: `p-2` (8px), `p-4` (16px), `p-6` (24px), `p-8` (32px)
- Section spacing: `py-16` or `py-24` for page sections
- Component internal: `p-4` to `p-6` for cards, `p-2` for compact elements
- Gap over margin: prefer `gap-4` in flex/grid over individual margins

### Typography
- Body text: minimum `text-base` (16px) on mobile — never smaller
- Line height: `leading-relaxed` (1.625) for body, `leading-tight` (1.25) for headings
- Line length: `max-w-prose` (65ch) for readability
- Font weight hierarchy: `font-bold` (headings), `font-medium` (subheadings), `font-normal` (body)

## Color & Theme

### Dark Mode
```tsx
// Tailwind dark mode via class strategy
<div className="bg-white dark:bg-slate-900 text-slate-900 dark:text-white">
```

### Light Mode Contrast (Common Mistakes)
| Element | Do | Don't |
|---------|-----|-------|
| Glass cards | `bg-white/80` | `bg-white/10` (invisible) |
| Body text | `text-slate-900` | `text-slate-400` (too light) |
| Muted text | `text-slate-600` minimum | `text-gray-400` |
| Borders | `border-gray-200` | `border-white/10` |

### Color Contrast
- Normal text: 4.5:1 minimum contrast ratio (WCAG AA)
- Large text (18px+ bold, 24px+ regular): 3:1 minimum
- Never use color as the only indicator — add icons, text, or patterns

## Interaction Patterns

### Hover & Focus
- All clickable elements: add `cursor-pointer`
- Smooth transitions: `transition-colors duration-200` or `transition-all duration-150`
- Hover feedback: color change, shadow, or border — never scale that shifts layout
- Focus rings: `focus:ring-2 focus:ring-blue-500 focus:ring-offset-2`

### Animations
- Duration: 150-300ms for micro-interactions
- Use `transform` and `opacity` for animations — never animate `width`/`height`
- Respect `prefers-reduced-motion`: `motion-reduce:transition-none`
- Skeleton screens for loading states over spinners

### Icons
- Use SVG icon libraries (Heroicons, Lucide, Simple Icons) — never emoji
- Consistent sizing: `w-5 h-5` (20px) for inline, `w-6 h-6` (24px) for standalone
- Icon-only buttons: always add `aria-label`

## Component Styling Patterns

### Cards
```tsx
<div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm 
                hover:shadow-md transition-shadow cursor-pointer">
```

### Buttons
```tsx
// Primary
<button className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white 
                    hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
                    disabled:opacity-50 disabled:cursor-not-allowed transition-colors">

// Secondary  
<button className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium
                    text-gray-700 hover:bg-gray-50 transition-colors">
```

### Forms
```tsx
<input className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm
                  focus:border-blue-500 focus:ring-1 focus:ring-blue-500 outline-none
                  placeholder:text-gray-400" />
```

### Floating Navbar
```tsx
<nav className="fixed top-4 left-4 right-4 z-50 rounded-2xl border border-gray-200/50 
                bg-white/80 backdrop-blur-lg px-6 py-3">
```
- Account for navbar height in page content: `pt-20` or similar

## CSS Performance (from Vercel)

- `content-visibility: auto` for long lists — skips rendering off-screen items
- Batch CSS changes via classes, not individual style properties
- Use `will-change` sparingly — only for known animation targets
- Avoid layout thrashing: read DOM measurements together, then write together

## Tailwind CSS v4 Migration Notes (2026)

Tailwind v4 is a complete rewrite using Rust/Oxide engine with major architectural changes:

### CSS-First Configuration
```css
/* No more tailwind.config.js — use @theme in CSS */
@import "tailwindcss";

@theme {
  --color-primary: #3b82f6;
  --font-display: "Inter", sans-serif;
  --breakpoint-3xl: 1920px;
}
```

### Breaking Class Renames
| v3 | v4 |
|----|----|
| `bg-gradient-to-*` | `bg-linear-to-*` |
| `flex-shrink-0` | `shrink-0` |
| `flex-grow` | `grow` |

### New Features
- **Container queries** built-in: `@container` parent + `@sm:` / `@md:` children (no plugin)
- **3D transforms** as utility classes
- One-line CSS import — no `@tailwind base/components/utilities` directives
- Builds 5x faster (full), 100x faster (incremental) vs v3

### Migration Command
```bash
npx @tailwindcss/upgrade   # Auto-renames ~90% of class changes
```

### Browser Requirements
Safari 16.4+, Chrome 111+, Firefox 128+ — stick with v3 for older browser support
