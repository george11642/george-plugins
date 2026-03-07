---
name: ui-design
description: "Master UI/UX design skill. Use when: designing UI components, layouts, landing pages, dashboards, mobile apps, colors/typography, accessibility audits, design reviews, visual art (canvas, p5.js, generative), presentations (PPTX, slides, posters), responsive design, interaction design, brand styling, glassmorphism, brutalism, minimalism, dark mode, component patterns (React, Vue, Svelte, shadcn/ui), charts, matplotlib, plotly, animation, gif, motion, design tokens, algorithmic art, Perlin noise, flow fields, form design, CRO, checkout form, inline validation, multi-step form, dark patterns, ethical design, inclusive design, cognitive accessibility, Core Web Vitals, LCP, CLS, INP, skeleton screens, prefers-reduced-motion, AI interface, chatbot UI, streaming text, LLM interface, optimistic UI, Style Dictionary, Tokens Studio. Elements: button, modal, navbar, sidebar, card, form, hero, pricing. File types: .html, .tsx, .vue, .svelte, .css, .scss, .pptx, .gif."
---

# UI Design - Master Skill

Consolidated design intelligence covering web/mobile UI, visual art, presentations, data visualization, and design systems. Routes to specialized reference files by task type.

## Skill Boundaries

Use this skill for web UI, visual art, and design system work. Defer to sibling skills when the task crosses into their domain:

| Task | Use This Skill? | Defer To |
|---|---|---|
| Web components (React, Vue, Svelte) | Yes | -- |
| React Native / Expo UI | No | `building-native-ui` (NativeWind, Expo Router) |
| Charts, matplotlib, plotly | Start here for chart selection | `data-viz` for complex dashboards, statistical viz |
| Video creation with React | No | `remotion-best-practices` |
| Presentations (PPTX, posters) | Start here for design | `presentations` for html2pptx pipeline |
| Next.js performance patterns | No | `vercel-react-best-practices` |

When in doubt: if the output is a native mobile screen, use `building-native-ui`. If the output is a data-heavy dashboard, co-invoke `data-viz`. This skill owns the visual design decisions; sibling skills own platform-specific implementation.

## Task Router

| User Intent | Reference File | Key Content |
|---|---|---|
| Accessibility, WCAG, a11y audit | `references/web-fundamentals.md` | WCAG 2.1 AA rules, ARIA, keyboard nav |
| Responsive design, breakpoints | `references/web-fundamentals.md` | Mobile-first breakpoints, touch targets |
| Interaction design, hover, animation | `references/web-fundamentals.md` | Transitions, z-index, cursor states |
| Color palette, typography, spacing | `references/design-system.md` | Palettes by product type, font pairings, scales |
| Brand styling (Anthropic) | `references/design-system.md` | Anthropic colors, fonts, accent palette |
| Choose a UI style | `references/styles-catalog.md` | 50+ styles with CSS guidance |
| Anti-patterns, AI slop avoidance | `references/styles-catalog.md` | Common mistakes to avoid |
| Charts, data visualization | `references/charts-and-dataviz.md` | Chart selection, library recs, matplotlib/plotly |
| React, Vue, Svelte components | `references/component-patterns.md` | Patterns, state, shadcn/ui, a11y checklist |
| Canvas art, poster design | `references/canvas-and-generative.md` | Philosophy-driven visual art creation |
| Generative art, p5.js, algorithmic | `references/canvas-and-generative.md` | p5.js implementation, interactive artifacts |
| Animated visualizations, Slack GIFs, motion | `references/animation-and-motion.md` | Easing functions, PIL animation, GIF constraints |
| Philosophy-driven design, manifesto, conceptual art | `references/philosophy-driven-design.md` | Manifesto process, subtle reference principle, craftsmanship checklist |
| Design system generation, theme selection, brand | `references/design-system-generation.md` | Product→style→color→type reasoning, MASTER.md persistence |
| Presentations, PPTX, slides | `references/presentations.md` | html2pptx, template workflow, OOXML |
| LaTeX posters | `references/presentations.md` | Scientific poster creation |
| Claude.ai artifacts | `references/web-artifacts.md` | React+TS+Tailwind artifact bundling |
| Apply a theme to artifact | `themes/` directory | 10 pre-built themes with color + font specs |
| MCP tools for design | `references/mcp-design-tools.md` | Stitch, Gemini, Figma, Chrome MCPs |
| Form design, CRO, conversion, checkout, inline validation | `references/form-design-and-cro.md` | Field psychology, field-by-field optimization, validation UX, mobile forms, trust elements, A/B testing |
| Design tokens, token architecture, light/dark mode tokens, CSS variables, cross-platform tokens, Style Dictionary, Tokens Studio | `references/design-system-tokens.md` | Primitive/semantic/component token hierarchy, CSS custom properties, dark mode strategy, platform compilation |
| Dark patterns, ethical design, inclusive design, privacy-first, cognitive accessibility, age-inclusive, ethical data visualization | `references/ethical-and-responsible-design.md` | Dark pattern checklist, cookie consent, permission requests, cognitive a11y, neurodiversity, inclusive imagery |
| Performance, Core Web Vitals, LCP, CLS, INP, skeleton screens, animation performance, GPU-accelerated, prefers-reduced-motion, Lighthouse | `references/performance-driven-design.md` | Speed philosophy, asset optimization, animation GPU rules, battery considerations, performance budget |
| AI interface, chatbot UI, conversational UI, LLM interface, streaming text, AI disclosure, optimistic UI, AI-generated designs | `references/ai-integrated-design.md` | Chat components, streaming patterns, adaptive interfaces, AI bias mitigation, anti-patterns |

## Craftsmanship Philosophy

Every visual output must appear meticulously crafted -- the product of deep expertise, not algorithmic generation. Apply these principles regardless of output format (web page, canvas art, presentation):

- **Intentionality over decoration**: every element earns its place. Remove before adding.
- **Spatial communication**: information lives in layout, hierarchy, and whitespace -- not in more text.
- **Material honesty**: glass effects feel like glass, shadows follow a consistent light source, surfaces have coherent depth.
- **Museum-quality finish**: alignment is pixel-perfect, color palettes are limited and intentional, typography pairs are deliberate. The result should withstand scrutiny at 200% zoom.

## MCP Integration

| Tool | Purpose | Discovery |
|---|---|---|
| Stitch | UI mockups & wireframes | `ToolSearch("stitch")` |
| Gemini | Image generation/editing | `gemini_image`, `gemini_image_edit` |
| Figma | Design specs extraction | `ToolSearch("figma")` |
| LaTeX | Scientific documents | `create_latex_file`, `edit_latex_file` |
| Chrome | Visual verification | `use_browser` for screenshots |
| shadcn/ui | Component search | `ToolSearch("shadcn")` |

## Quick Reference: Top 10 A11y Rules

1. **4.5:1 contrast** for normal text, 3:1 for large text
2. **Visible focus rings** on all interactive elements
3. **Alt text** on meaningful images, empty for decorative
4. **aria-label** on icon-only buttons
5. **Tab order** matches visual order
6. **44x44px minimum** touch targets
7. **`<label for>`** on all form inputs
8. **`prefers-reduced-motion`** respected
9. **Semantic HTML** (`nav`, `main`, `article`, `aside`)
10. **Color not sole indicator** of meaning

## Anti-Patterns Checklist

- No emojis as icons (use Heroicons, Lucide, Simple Icons SVGs)
- No `bg-white/10` glass in light mode (use `bg-white/80`+)
- No gray-400 text on white (minimum slate-600 for muted)
- No scale transforms on hover that shift layout
- No invisible borders (`border-white/10` in light mode)
- No content hidden behind fixed navbars
- No missing `cursor-pointer` on clickable elements
- No AI slop: centered layouts + purple gradients + Inter everywhere

## Pre-Delivery Checklist

### Visual Quality
- [ ] SVG icons from consistent set (no emojis)
- [ ] Brand logos verified (Simple Icons)
- [ ] Hover states don't shift layout
- [ ] Theme colors used directly (`bg-primary`, not `var()` wrappers)

### Interaction
- [ ] `cursor-pointer` on all clickable elements
- [ ] Smooth transitions (150-300ms)
- [ ] Focus states visible for keyboard nav
- [ ] Buttons disabled during async ops

### Responsive
- [ ] Works at 375px, 768px, 1024px, 1440px
- [ ] No horizontal scroll on mobile
- [ ] Touch targets >= 44x44px

### Accessibility
- [ ] All images have alt text
- [ ] Form inputs have labels
- [ ] `prefers-reduced-motion` respected
- [ ] Tested both light and dark modes
