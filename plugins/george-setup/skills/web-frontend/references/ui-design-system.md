# UI Design System

Comprehensive UI/UX design intelligence hub. Contains 67 styles, 96 color palettes, 57 font pairings, 25 chart types, 30 landing page patterns, 96 product-type recommendations, 99 UX guidelines, 100 UI reasoning rules, 100 icons, and 30 web interface guidelines. Sourced from ui-ux-pro-max.

## Reference Files

| File | Content | Count |
|---|---|---|
| `ui-design-styles.md` | UI styles with colors, effects, use cases, CSS variables | 67 styles |
| `ui-color-palettes.md` | Product-specific color palettes (Primary/Secondary/CTA/BG/Text/Border hex) | 96 palettes |
| `ui-font-pairings.md` | Font pairings with Google Fonts URLs, CSS imports, Tailwind config | 57 pairings |
| `ui-chart-types.md` | Chart type selection, color guidance, a11y notes, library recommendations | 25 charts |
| `ui-layout-patterns.md` | Landing page patterns, product-type mapping, UI reasoning rules | 30 patterns + 96 products + 100 reasoning rules |

## Design System Generation (CLI Tool)

For comprehensive recommendations with reasoning, use the search tool:

```bash
# Generate complete design system for a project
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<product_type> <industry> <keywords>" --design-system -p "Project Name"

# Persist design system with master + page overrides
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "Project Name"

# Domain-specific searches
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain style
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain color
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain typography
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain chart
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain landing
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain product
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain ux
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain icons
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain react
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain web

# Stack-specific guidelines
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --stack html-tailwind
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --stack react
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --stack nextjs
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --stack shadcn
```

Available stacks: html-tailwind, react, nextjs, vue, svelte, swiftui, react-native, flutter, shadcn, jetpack-compose, astro, nuxtjs, nuxt-ui

## Priority Rules

| Priority | Category | Impact | When to Check |
|---|---|---|---|
| 1 | Accessibility | CRITICAL | Every component |
| 2 | Touch & Interaction | CRITICAL | Every interactive element |
| 3 | Performance | HIGH | Every page/route |
| 4 | Layout & Responsive | HIGH | Every layout change |
| 5 | Typography & Color | MEDIUM | Design decisions |
| 6 | Animation | MEDIUM | Any motion added |
| 7 | Style Selection | MEDIUM | Project start |
| 8 | Charts & Data | LOW | Data visualization |

## Quick Reference: UX Guidelines (99 Rules)

### Accessibility (CRITICAL)
- Color contrast minimum 4.5:1 for normal text, 7:1 for AAA
- Visible focus rings on ALL interactive elements (`focus-visible:ring-2`)
- Descriptive alt text for meaningful images
- `aria-label` for icon-only buttons
- Tab order matches visual order
- `<label>` with `for` attribute on all form inputs
- Color is NOT the only indicator (add icons/text)
- Sequential heading levels h1-h6
- `aria-live="polite"` for async content updates
- Skip to main content link on nav-heavy pages
- Respect `prefers-reduced-motion`

### Touch & Interaction (CRITICAL)
- Minimum 44x44px touch targets, 8px gap between targets
- Use click/tap for primary interactions (hover is secondary)
- Disable button during async operations, show loading state
- Clear error messages near the problem field
- `cursor-pointer` on all clickable elements
- Confirmation dialog before destructive actions
- Active/pressed state visual feedback

### Performance (HIGH)
- WebP images with srcset, lazy loading below fold
- Check `prefers-reduced-motion` before animations
- Reserve space for async content (prevent layout shift)
- Font-display: swap, preconnect to CDN domains
- Virtualize lists >50 items
- Code split by route/feature

### Layout & Responsive (HIGH)
- `width=device-width, initial-scale=1` viewport
- Minimum 16px body text on mobile
- Content fits viewport width (no horizontal scroll)
- Z-index scale: 10 (sticky), 20 (dropdown), 30 (header), 40 (overlay), 50 (modal)
- Use `dvh` or account for mobile browser chrome (not `100vh`)
- Limit text to 65-75 characters per line (`max-w-prose`)
- Test at 320px, 375px, 414px, 768px, 1024px, 1440px

### Typography & Color (MEDIUM)
- Line height 1.5-1.75 for body text
- Consistent modular type scale
- Font loading with `font-display: swap` + similar fallback

### Animation (MEDIUM)
- 150-300ms for micro-interactions (never >500ms for UI)
- Use `transform` and `opacity` only (not width/height/top/left)
- Skeleton screens or spinners for loading states
- `ease-out` for entering, `ease-in` for exiting
- Animate max 1-2 key elements per view

### Forms
- Always show label above/beside input (never placeholder-only)
- Error message below related input field
- Validate on blur for most fields
- Use semantic input types (email, tel, number, url)
- `autocomplete` attribute for browser autofill
- Mark required fields with asterisk
- Show/hide password toggle
- `inputmode="numeric"` for number inputs on mobile
- Never block paste functionality

### Content & Feedback
- Truncate with ellipsis + expand option
- Use relative or locale-aware dates
- Format large numbers (1.2K, not 1234567)
- Show empty state with helpful message + action
- Toast notifications auto-dismiss 3-5 seconds
- Progress indicators for multi-step processes

## Common Rules for Professional UI

### Icons & Visual Elements
| Do | Don't |
|---|---|
| Use SVG icons (Lucide, Heroicons) | Use emojis as UI icons |
| Stable hover: color/opacity transitions | Scale transforms that shift layout |
| Consistent icon sizing (w-6 h-6) | Mix different icon sizes |
| Research official brand SVGs | Guess logo paths |

### Light/Dark Mode Contrast
| Do | Don't |
|---|---|
| `bg-white/80` or higher opacity in light | `bg-white/10` (too transparent) |
| `#0F172A` (slate-900) for text | `#94A3B8` (slate-400) for body text |
| `#475569` (slate-600) minimum for muted | gray-400 or lighter |
| `border-gray-200` in light mode | `border-white/10` (invisible) |

### Layout & Spacing
| Do | Don't |
|---|---|
| Floating navbar: `top-4 left-4 right-4` | Stick to `top-0 left-0 right-0` |
| Account for fixed navbar height | Let content hide behind fixed elements |
| Same `max-w-6xl` or `max-w-7xl` | Mix container widths |

## Pre-Delivery Checklist

### Visual Quality
- [ ] No emojis as icons (use SVG: Lucide, Heroicons)
- [ ] All icons from consistent set
- [ ] Brand logos verified (from Simple Icons)
- [ ] Hover states don't cause layout shift
- [ ] Use theme colors directly (bg-primary) not var() wrapper

### Interaction
- [ ] All clickable elements have `cursor-pointer`
- [ ] Hover states provide clear visual feedback
- [ ] Transitions 150-300ms
- [ ] Focus states visible for keyboard navigation

### Light/Dark Mode
- [ ] Light mode text sufficient contrast (4.5:1 minimum)
- [ ] Glass/transparent elements visible in light mode
- [ ] Borders visible in both modes
- [ ] Both modes tested

### Layout
- [ ] Floating elements have proper spacing from edges
- [ ] No content behind fixed navbars
- [ ] Responsive at 375px, 768px, 1024px, 1440px
- [ ] No horizontal scroll on mobile

### Accessibility
- [ ] All images have alt text
- [ ] Form inputs have labels
- [ ] Color is not the only indicator
- [ ] `prefers-reduced-motion` respected

## Icon Reference (Lucide React — 100 Icons)

Top icons by category. All use `import { IconName } from 'lucide-react'`:

**Navigation**: Menu, ArrowLeft, ArrowRight, ChevronDown, ChevronUp, Home, X, ExternalLink
**Action**: Plus, Minus, Trash2, Edit, Save, Download, Upload, Copy, Share, Search, Filter, Settings
**Status**: Check, CheckCircle, XCircle, AlertTriangle, AlertCircle, Info, Loader (animate-spin), Clock
**Communication**: Mail, MessageCircle, Phone, Send, Bell
**User**: User, Users, UserPlus, LogIn, LogOut
**Media**: Image, Video, Play, Pause, Volume2, Mic, Camera
**Commerce**: ShoppingCart, ShoppingBag, CreditCard, DollarSign, Tag, Gift, Percent
**Data**: BarChart, PieChart, TrendingUp, TrendingDown, Activity, Database
**Files**: File, FileText, Folder, FolderOpen, Paperclip, Link, Clipboard
**Layout**: Grid, List, Columns, Maximize, Minimize, Sidebar
**Social**: Heart, Star, ThumbsUp, ThumbsDown, Bookmark, Flag
**Security**: Lock, Unlock, Shield, Key, Eye, EyeOff
**Location**: MapPin, Map, Navigation, Globe
**Time**: Calendar, RefreshCw, RotateCcw, RotateCw
**Dev**: Code, Terminal, GitBranch, Github
