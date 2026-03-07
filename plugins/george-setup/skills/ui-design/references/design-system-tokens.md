# Design System Tokens

Architecture guide for design tokens — the single source of truth for design decisions across web, iOS, Android, and React Native.

The W3C Design Tokens Community Group released the first stable Design Tokens Specification (v1, 2025.10), establishing a vendor-neutral format. All major tools (Style Dictionary, Tokens Studio, Figma, Penpot, Sketch, Supernova) are converging on this standard.

---

## Token Architecture Philosophy

### Single Source of Truth
Design tokens are named, versioned design decisions stored in a format that can be consumed by any platform. The core principle: **define once, generate everywhere**.

```
Design decision (e.g., "primary brand blue")
        ↓
Token definition (brand.color.primary = #0066FF)
        ↓
Platform output:
  Web:          --color-primary: #0066FF;
  iOS:          UIColor.primary = UIColor(hex: "0066FF")
  Android:      <color name="color_primary">#0066FF</color>
  React Native: colors.primary = '#0066FF'
```

### Why Tokens Over Hardcoded Values
- **Theming**: Switch from light to dark mode by swapping a token set — not touching components
- **Multi-brand**: White-label products share components, vary only token files
- **Consistency**: All colors come from the palette — no one-off hex values in components
- **Change propagation**: Update a spacing unit in one place → all components update
- **Design-dev sync**: Designers and developers refer to the same named values

### The Three-Tier Token Hierarchy

```
Tier 1: Primitive / Global tokens
  ├── Raw values, no semantic meaning
  ├── color.blue.500 = #3B82F6
  ├── spacing.4 = 16px
  └── font-size.lg = 1.125rem

Tier 2: Semantic / Alias tokens
  ├── Reference primitives by their meaning
  ├── color.background.primary = {color.white}       (light mode)
  ├── color.background.primary = {color.neutral.950} (dark mode)
  ├── color.text.brand = {color.blue.500}
  └── spacing.component.padding-md = {spacing.4}

Tier 3: Component tokens
  ├── Scope to specific components
  ├── button.background.default = {color.text.brand}
  ├── button.padding.horizontal = {spacing.component.padding-md}
  └── input.border.color.focus = {color.text.brand}
```

**Why three tiers matter**:
- Primitives provide the full palette — component tokens never reference primitives directly
- Semantic tokens encode design decisions (what "primary" means in your system)
- Component tokens allow component-level customization without breaking the system

---

## Token Categories

### Color Tokens

**Primitive color scale (generate with oklch for perceptual uniformity)**:
```json
{
  "color": {
    "neutral": {
      "50":  { "$value": "#fafafa", "$type": "color" },
      "100": { "$value": "#f5f5f5", "$type": "color" },
      "200": { "$value": "#e5e5e5", "$type": "color" },
      "300": { "$value": "#d4d4d4", "$type": "color" },
      "400": { "$value": "#a3a3a3", "$type": "color" },
      "500": { "$value": "#737373", "$type": "color" },
      "600": { "$value": "#525252", "$type": "color" },
      "700": { "$value": "#404040", "$type": "color" },
      "800": { "$value": "#262626", "$type": "color" },
      "900": { "$value": "#171717", "$type": "color" },
      "950": { "$value": "#0a0a0a", "$type": "color" }
    },
    "brand": {
      "50":  { "$value": "#eff6ff", "$type": "color" },
      "500": { "$value": "#3b82f6", "$type": "color" },
      "600": { "$value": "#2563eb", "$type": "color" },
      "700": { "$value": "#1d4ed8", "$type": "color" }
    }
  }
}
```

**Semantic color tokens**:
```json
{
  "color": {
    "background": {
      "page":      { "$value": "{color.neutral.50}",  "$type": "color" },
      "surface":   { "$value": "{color.white}",        "$type": "color" },
      "subtle":    { "$value": "{color.neutral.100}",  "$type": "color" },
      "inverse":   { "$value": "{color.neutral.900}",  "$type": "color" }
    },
    "text": {
      "primary":   { "$value": "{color.neutral.900}",  "$type": "color" },
      "secondary":  { "$value": "{color.neutral.600}",  "$type": "color" },
      "disabled":  { "$value": "{color.neutral.400}",  "$type": "color" },
      "inverse":   { "$value": "{color.neutral.50}",   "$type": "color" },
      "brand":     { "$value": "{color.brand.600}",    "$type": "color" }
    },
    "border": {
      "default":   { "$value": "{color.neutral.200}",  "$type": "color" },
      "strong":    { "$value": "{color.neutral.300}",  "$type": "color" },
      "brand":     { "$value": "{color.brand.500}",    "$type": "color" }
    },
    "feedback": {
      "success":   { "$value": "#16a34a", "$type": "color" },
      "warning":   { "$value": "#d97706", "$type": "color" },
      "error":     { "$value": "#dc2626", "$type": "color" },
      "info":      { "$value": "#0284c7", "$type": "color" }
    }
  }
}
```

### Typography Tokens
```json
{
  "font": {
    "family": {
      "sans":  { "$value": "'Inter', system-ui, sans-serif", "$type": "fontFamily" },
      "mono":  { "$value": "'JetBrains Mono', 'Fira Code', monospace", "$type": "fontFamily" },
      "serif": { "$value": "'Playfair Display', Georgia, serif", "$type": "fontFamily" }
    },
    "size": {
      "xs":   { "$value": "0.75rem",  "$type": "dimension" },
      "sm":   { "$value": "0.875rem", "$type": "dimension" },
      "base": { "$value": "1rem",     "$type": "dimension" },
      "lg":   { "$value": "1.125rem", "$type": "dimension" },
      "xl":   { "$value": "1.25rem",  "$type": "dimension" },
      "2xl":  { "$value": "1.5rem",   "$type": "dimension" },
      "3xl":  { "$value": "1.875rem", "$type": "dimension" },
      "4xl":  { "$value": "2.25rem",  "$type": "dimension" },
      "5xl":  { "$value": "3rem",     "$type": "dimension" }
    },
    "weight": {
      "regular": { "$value": "400", "$type": "fontWeight" },
      "medium":  { "$value": "500", "$type": "fontWeight" },
      "semibold":{ "$value": "600", "$type": "fontWeight" },
      "bold":    { "$value": "700", "$type": "fontWeight" }
    },
    "line-height": {
      "tight":  { "$value": "1.25", "$type": "number" },
      "normal": { "$value": "1.5",  "$type": "number" },
      "relaxed":{ "$value": "1.75", "$type": "number" }
    },
    "letter-spacing": {
      "tight":  { "$value": "-0.02em", "$type": "dimension" },
      "normal": { "$value": "0",       "$type": "dimension" },
      "wide":   { "$value": "0.05em",  "$type": "dimension" },
      "widest": { "$value": "0.1em",   "$type": "dimension" }
    }
  }
}
```

### Spacing Tokens
Use a 4px base unit (most platforms align to 4px grid):
```json
{
  "spacing": {
    "0":  { "$value": "0",      "$type": "dimension" },
    "1":  { "$value": "4px",    "$type": "dimension" },
    "2":  { "$value": "8px",    "$type": "dimension" },
    "3":  { "$value": "12px",   "$type": "dimension" },
    "4":  { "$value": "16px",   "$type": "dimension" },
    "5":  { "$value": "20px",   "$type": "dimension" },
    "6":  { "$value": "24px",   "$type": "dimension" },
    "8":  { "$value": "32px",   "$type": "dimension" },
    "10": { "$value": "40px",   "$type": "dimension" },
    "12": { "$value": "48px",   "$type": "dimension" },
    "16": { "$value": "64px",   "$type": "dimension" },
    "20": { "$value": "80px",   "$type": "dimension" },
    "24": { "$value": "96px",   "$type": "dimension" }
  }
}
```

### Shadow Tokens
```json
{
  "shadow": {
    "sm":  { "$value": "0 1px 2px 0 rgba(0,0,0,0.05)", "$type": "shadow" },
    "md":  { "$value": "0 4px 6px -1px rgba(0,0,0,0.1)", "$type": "shadow" },
    "lg":  { "$value": "0 10px 15px -3px rgba(0,0,0,0.1)", "$type": "shadow" },
    "xl":  { "$value": "0 20px 25px -5px rgba(0,0,0,0.1)", "$type": "shadow" },
    "2xl": { "$value": "0 25px 50px -12px rgba(0,0,0,0.25)", "$type": "shadow" }
  }
}
```

### Motion Tokens
```json
{
  "motion": {
    "duration": {
      "instant":  { "$value": "50ms",  "$type": "duration" },
      "fast":     { "$value": "150ms", "$type": "duration" },
      "normal":   { "$value": "250ms", "$type": "duration" },
      "slow":     { "$value": "350ms", "$type": "duration" },
      "slower":   { "$value": "500ms", "$type": "duration" }
    },
    "easing": {
      "linear":      { "$value": "linear",                    "$type": "cubicBezier" },
      "ease-in":     { "$value": "cubic-bezier(0.4,0,1,1)",   "$type": "cubicBezier" },
      "ease-out":    { "$value": "cubic-bezier(0,0,0.2,1)",   "$type": "cubicBezier" },
      "ease-in-out": { "$value": "cubic-bezier(0.4,0,0.2,1)", "$type": "cubicBezier" },
      "spring":      { "$value": "cubic-bezier(0.34,1.56,0.64,1)", "$type": "cubicBezier" }
    }
  }
}
```

### Border Radius Tokens
```json
{
  "border-radius": {
    "none": { "$value": "0",      "$type": "dimension" },
    "sm":   { "$value": "2px",    "$type": "dimension" },
    "md":   { "$value": "6px",    "$type": "dimension" },
    "lg":   { "$value": "8px",    "$type": "dimension" },
    "xl":   { "$value": "12px",   "$type": "dimension" },
    "2xl":  { "$value": "16px",   "$type": "dimension" },
    "full": { "$value": "9999px", "$type": "dimension" }
  }
}
```

---

## CSS Custom Properties Implementation

### Root token definition
```css
:root {
  /* Primitive colors */
  --color-brand-50: #eff6ff;
  --color-brand-500: #3b82f6;
  --color-brand-600: #2563eb;
  --color-neutral-50: #fafafa;
  --color-neutral-100: #f5f5f5;
  --color-neutral-200: #e5e5e5;
  --color-neutral-900: #171717;

  /* Semantic tokens (reference primitives) */
  --color-bg-page: var(--color-neutral-50);
  --color-bg-surface: white;
  --color-bg-subtle: var(--color-neutral-100);
  --color-text-primary: var(--color-neutral-900);
  --color-text-secondary: var(--color-neutral-600);
  --color-text-brand: var(--color-brand-600);
  --color-border-default: var(--color-neutral-200);

  /* Spacing */
  --spacing-1: 4px;
  --spacing-2: 8px;
  --spacing-4: 16px;
  --spacing-6: 24px;
  --spacing-8: 32px;

  /* Typography */
  --font-family-sans: 'Inter', system-ui, sans-serif;
  --font-size-base: 1rem;
  --font-size-sm: 0.875rem;
  --font-size-lg: 1.125rem;

  /* Motion */
  --duration-fast: 150ms;
  --duration-normal: 250ms;
  --ease-out: cubic-bezier(0,0,0.2,1);
}
```

---

## Light/Dark Mode Token Strategy

### Method 1: data-theme attribute (recommended for programmatic switching)
```css
:root,
[data-theme="light"] {
  --color-bg-page: #fafafa;
  --color-bg-surface: #ffffff;
  --color-text-primary: #171717;
  --color-text-secondary: #525252;
  --color-border-default: #e5e5e5;
}

[data-theme="dark"] {
  --color-bg-page: #0a0a0a;
  --color-bg-surface: #171717;
  --color-text-primary: #fafafa;
  --color-text-secondary: #a3a3a3;
  --color-border-default: #262626;
}
```

```javascript
// Toggle
document.documentElement.setAttribute('data-theme',
  currentTheme === 'dark' ? 'light' : 'dark'
);

// Initialize from localStorage with OS fallback
const saved = localStorage.getItem('theme');
const preferred = window.matchMedia('(prefers-color-scheme: dark)').matches
  ? 'dark' : 'light';
document.documentElement.setAttribute('data-theme', saved ?? preferred);
```

### Method 2: prefers-color-scheme (CSS-only, no JS)
```css
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg-page: #0a0a0a;
    --color-text-primary: #fafafa;
  }
}
```

### Method 3: Combined (OS default + user override)
```css
/* OS default */
@media (prefers-color-scheme: dark) {
  :root { --color-bg-page: #0a0a0a; }
}

/* User override overrides OS */
[data-theme="light"] { --color-bg-page: #fafafa; }
[data-theme="dark"]  { --color-bg-page: #0a0a0a; }
```

### Dark Mode Token Design Rules
- Never invert: dark mode is not `color: white; background: black` — it's a separate token set
- Use mid-range neutrals for surfaces in dark mode (900 for base, 800 for cards, 700 for hover)
- Reduce saturation of brand colors by 10-15% in dark mode (vibrant colors are harsher in dark)
- Shadows become subtle glow effects: `box-shadow: 0 4px 20px rgba(59,130,246,0.15)`

---

## Platform Compilation with Style Dictionary

### Install and configure
```bash
npm install style-dictionary
```

```javascript
// style-dictionary.config.js
import StyleDictionary from 'style-dictionary';

export default {
  source: ['tokens/**/*.json'],
  platforms: {
    css: {
      transformGroup: 'css',
      prefix: 'sd',
      buildPath: 'dist/css/',
      files: [{ destination: 'variables.css', format: 'css/variables' }]
    },
    ios: {
      transformGroup: 'ios-swift',
      buildPath: 'dist/ios/',
      files: [{
        destination: 'StyleDictionaryColor.swift',
        format: 'ios-swift/enum.swift',
        filter: { attributes: { category: 'color' } }
      }]
    },
    android: {
      transformGroup: 'android',
      buildPath: 'dist/android/',
      files: [
        { destination: 'colors.xml', format: 'android/colors' },
        { destination: 'dimens.xml', format: 'android/dimens' }
      ]
    }
  }
};
```

### Generated output examples

**Web CSS**:
```css
:root {
  --sd-color-brand-500: #3b82f6;
  --sd-color-text-primary: #171717;
  --sd-spacing-4: 16px;
}
```

**iOS Swift**:
```swift
public enum StyleDictionaryColor {
  public static let brandPrimary = UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
  public static let textPrimary  = UIColor(red: 0.090, green: 0.090, blue: 0.090, alpha: 1)
}
```

**Android XML**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<resources>
  <color name="color_brand_500">#3b82f6</color>
  <color name="color_text_primary">#171717</color>
  <dimen name="spacing_4">16dp</dimen>
</resources>
```

**React Native (via NativeWind or plain StyleSheet)**:
```javascript
// dist/js/tokens.js
export const tokens = {
  color: {
    brand: { 500: '#3b82f6' },
    text:  { primary: '#171717' }
  },
  spacing: { 4: 16 }
};
```

---

## Cross-Platform: NativeWind Mapping

NativeWind v4 brings CSS custom properties to React Native:

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          500: 'var(--color-brand-500)',  // References CSS custom property
          600: 'var(--color-brand-600)',
        },
        'text-primary': 'var(--color-text-primary)',
      }
    }
  }
};
```

```javascript
// globals.css (loaded in _layout.tsx)
:root {
  --color-brand-500: #3b82f6;
  --color-text-primary: #171717;
}
```

For platforms without CSS variable support, use the token JS object:
```javascript
import { tokens } from '@/design-tokens';
const styles = StyleSheet.create({
  heading: {
    color: tokens.color.text.primary,
    fontSize: tokens.font.size.xl,
  }
});
```

---

## Token Naming Conventions

### Pattern: `{tier}.{category}.{property}.{variant}.{state}`

```
color.background.surface           → bg surface token
color.background.surface.hover     → hover state variant
color.text.brand.strong            → stronger brand text
spacing.component.button.padding-x → button-specific spacing
border-radius.component.card       → card corner radius
font.size.heading.h1               → h1 font size
motion.duration.interaction        → interaction timing
shadow.component.card.elevated     → elevated card shadow
```

### Naming rules
- Use kebab-case for all token names
- Never encode the value in the name: `color.blue` is bad; `color.brand.primary` is good
- Don't encode the theme: no `color.dark-background`; use semantic names that work in both themes
- Be consistent with pluralization: `colors` vs `color` — pick one and stick with it

---

## Tokens Studio for Figma

Tokens Studio (formerly Figma Tokens) is the industry standard for managing tokens in Figma:

1. Install the Tokens Studio plugin in Figma
2. Connect to your token JSON source (GitHub, GitLab, URL, or local)
3. Tokens sync bidirectionally: Figma variables ↔ JSON token files
4. Style Dictionary consumes the JSON to generate platform outputs

**Workflow**:
```
Designer in Figma → Tokens Studio plugin → GitHub token repo
→ Style Dictionary CI build → CSS/Swift/XML/JS output
→ Platform repositories consume platform-specific output
```

**W3C token format support**:
As of 2025, Tokens Studio supports the W3C stable spec. Use `$value` and `$type` properties:
```json
{
  "color-primary": {
    "$value": "#3b82f6",
    "$type": "color",
    "$description": "Primary brand color — use for CTAs and links"
  }
}
```

---

## Token Versioning and Deprecation Strategy

### Semantic versioning for token files
- **Patch** (1.0.1): Color value tweaks, minor adjustments
- **Minor** (1.1.0): New tokens added, no removals
- **Major** (2.0.0): Tokens renamed, removed, or restructured

### Deprecation workflow
```json
{
  "color-primary-old": {
    "$value": "{color.brand.500}",
    "$type": "color",
    "$description": "DEPRECATED: Use color.text.brand instead. Will be removed in v3.0."
  }
}
```

1. Mark token as deprecated with `$description`
2. Keep deprecated token for one major version
3. Generate lint warnings in consuming codebases
4. Remove in next major version after migration period

### Migration tooling
Style Dictionary can be extended with custom transforms that emit console warnings for deprecated token usage:
```javascript
StyleDictionary.registerTransform({
  name: 'warn/deprecated',
  type: 'value',
  matcher: (token) => token.$description?.includes('DEPRECATED'),
  transformer: (token) => {
    console.warn(`Token "${token.name}" is deprecated: ${token.$description}`);
    return token.$value;
  }
});
```

---

## Working Example: Complete Token Set for a SaaS Product

### File structure
```
tokens/
  primitives/
    colors.json       # Raw palette
    typography.json   # Font values
    spacing.json      # Spacing scale
  semantic/
    light.json        # Light mode semantic tokens
    dark.json         # Dark mode semantic tokens
  components/
    button.json       # Button-specific tokens
    input.json        # Input-specific tokens
    card.json         # Card-specific tokens
  index.json          # Aggregator / $extends chains
```

### Quick reference: minimum viable token set
For a new design system, start with these 20 semantic tokens and expand:

```json
{
  "color": {
    "bg":      { "page": "", "surface": "", "subtle": "", "inverse": "" },
    "text":    { "primary": "", "secondary": "", "disabled": "", "brand": "", "inverse": "" },
    "border":  { "default": "", "strong": "", "brand": "" },
    "brand":   { "default": "", "hover": "", "active": "" },
    "feedback":{ "success": "", "warning": "", "error": "" }
  }
}
```
