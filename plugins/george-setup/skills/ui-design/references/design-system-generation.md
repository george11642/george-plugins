# Design System Generation

A complete design system is derived through structured reasoning, not guesswork. This document covers the full workflow: from reading user intent through product type → style → color → typography reasoning, to persisting the design system for cross-session retrieval, to generating custom themes when nothing pre-built fits.

---

## The Reasoning Framework

Every design system decision is downstream of product type. The correct order is:

```
Product Type → Industry Context → Style Selection → Color Palette → Typography → Effects
```

Never start with "I'll use Inter and a blue color scheme." Start with: "What kind of product is this, who uses it, and what emotional register does it need?"

### Step 1: Identify Product Type and Context

Extract from the user's request:

| Dimension | Extract | Example |
|---|---|---|
| Product type | What is it? | SaaS dashboard, e-commerce store, portfolio, landing page, admin panel |
| Industry | What sector? | Healthcare, fintech, beauty/wellness, gaming, education, logistics |
| Audience | Who uses it? | Professionals, consumers, executives, developers, patients |
| Style keywords | Any stated preferences | "clean," "bold," "playful," "enterprise," "luxury," "minimal" |
| Stack | Framework? | React, Vue, Next.js — default `html-tailwind` if unspecified |

### Step 2: Apply Style Reasoning Rules

Match product context to appropriate style direction. The rule: **match style to product type and audience expectations, then push the craft level as high as possible within that style**.

| Product Type | Typical Style Direction | Avoid |
|---|---|---|
| Healthcare SaaS | Clean minimalism, trust-building blues/greens | Dark mode (anxiety-inducing), aggressive contrast |
| Fintech/crypto | Tech-forward, precision, dark mode or neutral | Playful gradients, rounded corners |
| Beauty/wellness | Soft, warm, luxurious — editorial photography driven | Technical aesthetics, harsh angles |
| Gaming/entertainment | High contrast, bold typography, energetic color | Corporate minimalism |
| Developer tools | Dark mode default, code-optimized typography, no decoration | Marketing aesthetics |
| Portfolio/creative | Open-ended — match creator's discipline | Generic templates, clip-art aesthetic |
| E-commerce | Conversion-optimized, trust signals, clean product focus | Visual complexity that distracts from products |
| Education | Approachable, structured, accessible contrast | Dense information architecture |

### Step 3: Derive Color Palette

Color follows product type and emotional register. Do not pick colors arbitrarily.

**Color reasoning by product type:**

| Product Context | Palette Direction | Example |
|---|---|---|
| Medical/healthcare | Calm blues, clean whites, green accents (healing) | #0EA5E9, #FFFFFF, #22C55E |
| Finance/professional | Deep navy or neutral base, precision accents | #0F172A, #3B82F6, #64748B |
| Beauty/luxury | Warm neutrals, blush tones, gold accents | #FAF5F0, #D4A574, #2D1B14 |
| Sustainability/eco | Earth tones, forest greens, warm beiges | #3D6B35, #8B7355, #F5F0E8 |
| Tech startup | Electric accents on neutral base — purple, cyan, orange | #6366F1, #0F172A, #F8FAFC |
| Creative agency | High contrast, distinctive accent, intentional asymmetry | Context-dependent |
| E-commerce | High contrast for CTAs, neutral canvas for products | #1A1A1A, #FFFFFF, brand color CTA |

**Palette structure (always):**
- **Background**: 1-2 values (light mode: near-white; dark mode: deep neutral)
- **Surface**: Card/component backgrounds, slightly offset from background
- **Text**: Primary (high contrast), secondary (muted but accessible), muted (supplementary)
- **Brand/Primary**: The identity color — 1 main, 1 lighter tint for interactive states
- **Accent**: For CTAs, highlights, and interactive feedback
- **Semantic**: Success (green), error (red), warning (amber), info (blue)

### Step 4: Select Typography

Typography follows personality, not trend. Inter is not the answer to every question.

| Personality Need | Heading Font | Body Font | Feel |
|---|---|---|---|
| Premium / editorial | Playfair Display | Source Sans Pro | Magazine, luxury |
| Tech / precision | IBM Plex Mono | IBM Plex Sans | Developer, crisp |
| Warm / approachable | Nunito | Open Sans | Consumer, friendly |
| Bold / assertive | Space Grotesk | Inter | Modern SaaS, startup |
| Scientific / academic | Libre Baskerville | Lato | Research, authority |
| Minimal / elegant | Cormorant Garamond | Raleway | Design-forward |
| Playful / creative | Pacifico or Righteous | Nunito | Entertainment, young audience |
| Enterprise / formal | Georgia | Source Sans Pro | Corporate, institutional |

**Typography scale (always define):**
```
Display: 4-6rem / Bold
H1: 2.5-3rem / Semibold
H2: 2rem / Semibold
H3: 1.5rem / Medium
Body: 1rem / Regular — line-height 1.5-1.75
Small: 0.875rem / Regular
Caption: 0.75rem / Regular
```

---

## Priority Matrix

When design decisions conflict, apply this priority order:

| Priority | Category | Level | Rationale |
|---|---|---|---|
| 1 | Accessibility | CRITICAL | Legal requirement + morally non-negotiable. 4.5:1 contrast minimum. |
| 2 | Touch & Interaction | CRITICAL | Broken interactions destroy product trust instantly. |
| 3 | Performance | HIGH | Slow UI signals unreliable product. |
| 4 | Layout & Responsive | HIGH | Broken layout on any breakpoint is unshippable. |
| 5 | Typography & Color | MEDIUM | Craft matters but is not a blocker. |
| 6 | Animation | MEDIUM | Enhances quality when done right, distracts when not. |
| 7 | Style Selection | MEDIUM | Wrong style is recoverable; wrong accessibility is not. |
| 8 | Charts & Data | LOW | Important for specific pages, not universal. |

Never sacrifice accessibility for aesthetic choices. Never sacrifice interaction correctness for visual polish.

---

## Design System Persistence: MASTER.md + pages/*.md

For multi-page projects, persist the design system using a hierarchical file structure.

### File Hierarchy

```
design-system/
  MASTER.md              ← Global source of truth for the project
  pages/
    dashboard.md         ← Overrides for the dashboard page
    checkout.md          ← Overrides for the checkout flow
    landing.md           ← Overrides for the marketing landing page
```

### MASTER.md Contents

The master file contains the complete design system:

```markdown
# Design System: [Project Name]

## Identity
- Product type: [SaaS / e-commerce / etc.]
- Style direction: [e.g., "Minimal enterprise with warm accents"]
- Target audience: [e.g., "Finance professionals, 30-50"]

## Color Palette
- Background: #FAFAFA
- Surface: #FFFFFF
- Primary text: #0F172A
- Secondary text: #475569
- Muted text: #94A3B8
- Brand primary: #3B82F6
- Brand primary hover: #2563EB
- Accent: #F59E0B
- Success: #22C55E / Error: #EF4444 / Warning: #F59E0B

## Typography
- Heading font: [Font name] — Weight: 600/700
- Body font: [Font name] — Weight: 400/500
- Code font: [Font name or monospace]
- Scale: [Display/H1/H2/H3/body/small/caption sizes]

## Spacing & Layout
- Base unit: 4px (Tailwind default)
- Content max-width: max-w-6xl (1152px)
- Section padding: py-20 px-6
- Card padding: p-6

## Component Patterns
- Border radius: rounded-xl for cards, rounded-lg for buttons
- Shadow level: shadow-sm default, shadow-md on hover
- Border: border border-gray-200 in light mode

## Effects & Animations
- Transition duration: 150-300ms
- Hover: opacity or color shift, never scale shift
- Skeleton screens for async content

## Anti-Patterns for This Project
- [List specific things to avoid based on the product type]
```

### Page Override Files

Page-specific files contain only the deltas from MASTER.md:

```markdown
# Dashboard Page Overrides

## Background
- Use dark mode variant: bg-slate-900 instead of #FAFAFA
- Data density: compact spacing (py-2 instead of py-4 for table rows)

## Components
- Table row hover: bg-slate-800 (dark mode)
- Chart color sequence: [specific palette for this page's charts]

## Typography
- Data values: tabular-nums for alignment
```

### Hierarchical Retrieval Protocol

When building a specific page:
1. Check if `design-system/pages/[page-name].md` exists
2. If it exists: its rules **override** the Master file
3. If it does not exist: use `design-system/MASTER.md` exclusively

**Context-aware retrieval prompt for agents:**
```
I am building the [Page Name] page. Please read design-system/MASTER.md.
Also check if design-system/pages/[page-name].md exists.
If the page file exists, prioritize its rules.
If not, use the Master rules exclusively.
Now, generate the code...
```

---

## Eight Domain Search Strategies

When using the `ui-ux-pro-max` script or reasoning from first principles, search these eight domains:

| Domain | Purpose | Example Keywords |
|---|---|---|
| `product` | Product type pattern recommendations | SaaS, e-commerce, portfolio, healthcare, beauty, service |
| `style` | UI style and visual effect options | glassmorphism, minimalism, dark mode, brutalism, neumorphism |
| `typography` | Font pairings, Google Fonts recommendations | elegant, playful, professional, modern, luxury |
| `color` | Color palettes organized by product type | saas, ecommerce, healthcare, beauty, fintech, service |
| `landing` | Landing page structure and CTA strategies | hero, testimonial, pricing, social-proof, conversion |
| `chart` | Chart type selection by data type | trend, comparison, timeline, funnel, distribution |
| `ux` | Best practices, accessibility, anti-patterns | animation, accessibility, z-index, loading states |
| `react` | React/Next.js performance patterns | waterfall, bundle, suspense, memo, rerender, cache |

**For a new project, always run at minimum**: `product`, `color`, `typography`.

**For data-heavy products**: also run `chart` and `ux`.

**For landing pages**: also run `landing` and `style`.

---

## Custom Theme Generation

When no pre-built theme fits, generate a custom theme using the reasoning framework above.

### Process

1. **Extract identity descriptors** from the project: 3-5 adjectives that describe the emotional register (e.g., "warm, premium, editorial, calm, authoritative")
2. **Derive the color palette** from those descriptors using the color reasoning table
3. **Derive typography** from personality need
4. **Name the theme** as a 2-word descriptor (e.g., "Warm Precision," "Arctic Editorial," "Deep Trust")
5. **Document the theme** in the project's design system

### Custom Theme Template

```markdown
## Theme: [Name]

**Identity**: [2-3 sentence description of the aesthetic and emotional register]

### Color Palette
| Role | Light Mode | Dark Mode |
|---|---|---|
| Background | #FAFAF8 | #0F1117 |
| Surface | #FFFFFF | #1A1D27 |
| Primary text | #1A1A2E | #F1F5F9 |
| Secondary text | #4A4A6A | #94A3B8 |
| Brand primary | #[hex] | #[hex] |
| Brand accent | #[hex] | #[hex] |
| Success | #22C55E | #4ADE80 |
| Error | #EF4444 | #F87171 |

### Typography
- Heading: [Font] — [Weight]
- Body: [Font] — [Weight]
- Rationale: [Why these fonts fit the identity]

### When to use
[Description of product types or contexts this theme suits]
```

---

## Design System Generation Checklist

### Reasoning Phase
- [ ] Product type identified (not just "website" but specific category)
- [ ] Industry context established
- [ ] Audience understood
- [ ] Style direction derived from product/audience logic
- [ ] Color palette chosen with explicit reasoning
- [ ] Typography pair chosen for personality fit

### Documentation Phase
- [ ] MASTER.md created with complete palette, type scale, spacing
- [ ] Component patterns documented (border-radius, shadow, border)
- [ ] Anti-patterns listed for this specific project
- [ ] Semantic colors included (success/error/warning/info)

### Validation Phase
- [ ] All color combinations pass 4.5:1 contrast ratio (WCAG AA)
- [ ] Touch targets will be >= 44x44px
- [ ] Design system consistent with stated style direction
- [ ] No arbitrary choices — every decision has a rationale

---

## Common Anti-Patterns in Design System Generation

| Anti-Pattern | Problem | Correct Approach |
|---|---|---|
| "I'll use Inter for everything" | Generic, zero differentiation | Choose typography from personality analysis |
| "Blue is a safe choice" | Not derived from product context | Derive from industry/audience/emotion analysis |
| Purple gradient + centered layout | AI slop — immediately recognizable as generated | Derive style from product type, not defaults |
| No semantic colors | Inconsistent error/success states | Always define all 4 semantic colors |
| Missing dark mode values | Half-baked design system | Either commit to light-only or define both modes |
| No spacing system | Inconsistent layouts across pages | Define base unit (4px) and named spacing scale |
| Copy-pasting a component library's theme | No design identity | Build from product reasoning first, then pick library |
