# Accessibility Patterns

Consolidated from: ui-ux-pro-max, vercel-react-best-practices

## Critical Rules (WCAG AA)

### Color & Contrast
- **4.5:1** minimum contrast ratio for normal text (<18px or <14px bold)
- **3:1** minimum for large text (18px+ or 14px+ bold)
- **3:1** minimum for UI components and graphical objects
- Never use color as the sole indicator — add text, icons, or patterns
- Test with grayscale filter to verify information survives

### Keyboard Navigation
- All interactive elements must be keyboard accessible
- Tab order must match visual reading order
- Visible focus indicators: `focus:ring-2 focus:ring-blue-500 focus:ring-offset-2`
- Skip navigation link for content-heavy pages
- Trap focus inside modals — return focus on close

### Semantic HTML
- Use `<button>` for actions, `<a>` for navigation — never `<div onClick>`
- Heading hierarchy: one `<h1>`, sequential `<h2>`-`<h6>` without skipping
- `<nav>`, `<main>`, `<aside>`, `<footer>` landmarks for screen readers
- `<ul>`/`<ol>` for lists, `<table>` with `<th>` for tabular data

### Forms
- Every `<input>` needs a visible `<label>` with `htmlFor` matching `id`
- Error messages: adjacent to field, specific ("Email is required"), not just red border
- Required fields: use `aria-required="true"` and visual indicator
- Group related inputs with `<fieldset>` and `<legend>`
- `autocomplete` attribute for personal info fields

### ARIA (use sparingly)
- First rule of ARIA: don't use ARIA if native HTML works
- `aria-label` for icon-only buttons: `<button aria-label="Close menu">`
- `aria-live="polite"` for dynamic content updates (toast, status)
- `aria-expanded` for toggleable sections (accordions, dropdowns)
- `role="dialog"` + `aria-modal="true"` for modals

### Images & Media
- `alt` text: descriptive for meaningful images, empty `alt=""` for decorative
- Video: captions and transcripts
- Audio: transcripts
- `prefers-reduced-motion`: disable non-essential animations

### Touch Targets
- Minimum 44x44px touch/click targets on mobile
- Adequate spacing between interactive elements (minimum 8px gap)
- Don't rely on hover for critical interactions — mobile has no hover

## Testing Checklist
- [ ] Tab through entire page — all interactive elements reachable
- [ ] Screen reader announces content logically (VoiceOver/NVDA)
- [ ] Color contrast passes (use browser DevTools audit)
- [ ] Page works at 200% zoom without horizontal scroll
- [ ] All images have appropriate alt text
- [ ] Forms are usable with keyboard only
- [ ] Error states are perceivable without color alone
- [ ] `prefers-reduced-motion` is respected
