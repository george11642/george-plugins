# Web Fundamentals: Accessibility, Responsive, Interaction Design

## Accessibility (WCAG 2.1 AA — CRITICAL)

### Color & Contrast
- **4.5:1** minimum contrast ratio for normal text (< 18pt)
- **3:1** minimum for large text (>= 18pt or >= 14pt bold)
- Color must never be the **only** indicator of meaning
- Test with tools: Chrome DevTools contrast checker, axe-core

### Keyboard Navigation
- All interactive elements must be reachable via Tab
- Tab order must match visual reading order
- Visible focus rings on all interactive elements (`outline: 2px solid`, never `outline: none` without replacement)
- Skip-to-content link as first focusable element
- Escape closes modals/popups and returns focus to trigger

### Screen Readers & ARIA
- Semantic HTML first: `<nav>`, `<main>`, `<article>`, `<aside>`, `<header>`, `<footer>`
- `aria-label` for icon-only buttons
- `aria-live="polite"` for dynamic content updates
- `aria-expanded` for collapsible sections
- `role="alert"` for error messages
- Alt text: descriptive for meaningful images, empty `alt=""` for decorative
- Form inputs always paired with `<label for="id">`

### Motion & Animation
- Respect `prefers-reduced-motion: reduce` — disable or simplify animations
- No auto-playing animations that flash more than 3 times per second
- Provide pause/stop controls for any animation lasting > 5 seconds

## Responsive Design

### Breakpoints (mobile-first)
| Name | Min-width | Target |
|------|-----------|--------|
| sm | 640px | Large phones |
| md | 768px | Tablets |
| lg | 1024px | Small laptops |
| xl | 1280px | Desktops |
| 2xl | 1536px | Large screens |

### Layout Rules
- `viewport meta`: `width=device-width, initial-scale=1`
- Minimum 16px body text on mobile (browser zoom-safe)
- No horizontal scroll — all content fits viewport width
- Touch targets: minimum 44x44px with 8px spacing between
- Readable line length: 65-75 characters (`max-w-prose` or `max-w-2xl`)
- Images: use `srcset`, `sizes`, WebP format, lazy loading (`loading="lazy"`)
- Reserve space for async content to prevent layout shift (CLS)

### Container Strategy
- Use consistent `max-w-6xl` or `max-w-7xl` across pages
- Content padding: `px-4` mobile, `px-6` tablet, `px-8` desktop
- Account for fixed navbar height in content padding

## Interaction Design

### Feedback Patterns
- Hover: color/opacity transitions (150-300ms), never scale transforms that shift layout
- Click: visual press state, disable button during async operations
- Loading: skeleton screens > spinners > text indicators
- Errors: inline near the problem field, not just toast notifications
- Success: brief confirmation, auto-dismiss after 3-5 seconds

### Cursor States
- `cursor-pointer` on all clickable/hoverable elements
- `cursor-not-allowed` on disabled elements
- `cursor-grab` / `cursor-grabbing` for draggable elements

### Transitions
- Micro-interactions: 150-300ms
- Page transitions: 300-500ms
- Use `transform` and `opacity` for GPU-accelerated animation
- Never animate `width`, `height`, `top`, `left` (causes reflow)
- Easing: `ease-out` for enters, `ease-in` for exits, `ease-in-out` for state changes

### Z-Index Scale
| Layer | Value | Use |
|-------|-------|-----|
| Base | 0 | Default content |
| Dropdown | 10 | Menus, dropdowns |
| Sticky | 20 | Sticky headers |
| Fixed | 30 | Fixed navbars |
| Modal backdrop | 40 | Overlay backgrounds |
| Modal | 50 | Modal dialogs |
| Toast | 60 | Notifications |
| Tooltip | 70 | Tooltips |
