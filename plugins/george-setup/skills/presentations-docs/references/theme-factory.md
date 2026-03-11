# Theme Factory Reference

Pre-built professional themes with complete color palettes and font pairings. Apply to slides, HTML, documents, posters, or any visual artifact.

## Quick Theme Selection Workflow

```
1. Show theme showcase → ask user which theme to apply
2. Read theme spec from this file
3. Apply colors and fonts consistently throughout the artifact
4. Ensure contrast and readability on all elements
```

**When to use pre-built themes**: User wants a cohesive look quickly, no specific brand constraints, or asks for "a good theme."

**When to design from scratch**: User provides brand colors/fonts, needs a custom identity, or none of the 10 themes fit the content.

---

## Theme Showcase

Display `~/.claude/skills/_archive/theme-factory/theme-showcase.pdf` to show all themes visually. Do not modify it; show it for viewing only.

---

## The 10 Pre-Built Themes

### 1. Ocean Depths
*Professional and calming maritime theme.*

**Color Palette**:
- Deep Navy `#1a2332` — primary background
- Teal `#2d8b8b` — accent, highlights, emphasis
- Seafoam `#a8dadc` — secondary accent, lighter elements
- Cream `#f1faee` — text, light backgrounds

**Typography**:
- Headers: DejaVu Sans Bold
- Body: DejaVu Sans

**Best for**: Corporate presentations, financial reports, consulting decks, trust-building content.

---

### 2. Sunset Boulevard
*Warm and vibrant, inspired by golden hour.*

**Color Palette**:
- Burnt Orange `#e76f51` — primary accent
- Coral `#f4a261` — secondary warm accent
- Warm Sand `#e9c46a` — highlights, backgrounds
- Deep Purple `#264653` — dark contrast, text

**Typography**:
- Headers: DejaVu Serif Bold
- Body: DejaVu Sans

**Best for**: Creative pitches, marketing, lifestyle brands, event promotions, inspirational content.

---

### 3. Forest Canopy
*Natural and grounded, dense forest earth tones.*

**Color Palette**:
- Forest Green `#2d4a2b` — primary dark green
- Sage `#7d8471` — muted green accent
- Olive `#a4ac86` — light accent
- Ivory `#faf9f6` — backgrounds, text

**Typography**:
- Headers: FreeSerif Bold
- Body: FreeSans

**Best for**: Environmental, sustainability, outdoor brands, wellness, organic products.

---

### 4. Modern Minimalist
*Clean and contemporary, maximum versatility.*

**Color Palette**:
- Charcoal `#36454f` — primary dark
- Slate Gray `#708090` — medium gray, accents
- Light Gray `#d3d3d3` — backgrounds, dividers
- White `#ffffff` — text, clean backgrounds

**Typography**:
- Headers: DejaVu Sans Bold
- Body: DejaVu Sans

**Best for**: Tech presentations, architecture portfolios, design showcases, modern business proposals, data visualization.

---

### 5. Golden Hour
*Rich and warm autumnal palette.*

**Color Palette**:
- Mustard Yellow `#f4a900` — bold primary accent
- Terracotta `#c1666b` — warm secondary
- Warm Beige `#d4b896` — neutral backgrounds
- Chocolate Brown `#4a403a` — dark text, anchors

**Typography**:
- Headers: FreeSans Bold
- Body: FreeSans

**Best for**: Restaurants, hospitality, fall campaigns, cozy lifestyle, artisan products.

---

### 6. Arctic Frost
*Cool and crisp, winter-inspired clarity.*

**Color Palette**:
- Ice Blue `#d4e4f7` — light backgrounds, highlights
- Steel Blue `#4a6fa5` — primary accent
- Silver `#c0c0c0` — metallic accent elements
- Crisp White `#fafafa` — clean backgrounds, text

**Typography**:
- Headers: DejaVu Sans Bold
- Body: DejaVu Sans

**Best for**: Healthcare, technology solutions, winter sports, clean tech, pharmaceutical content.

---

### 7. Desert Rose
*Soft and sophisticated, dusty muted tones.*

**Color Palette**:
- Dusty Rose `#d4a5a5` — soft primary
- Clay `#b87d6d` — earthy accent
- Sand `#e8d5c4` — warm neutral backgrounds
- Deep Burgundy `#5d2e46` — rich dark contrast

**Typography**:
- Headers: FreeSans Bold
- Body: FreeSans

**Best for**: Fashion, beauty brands, wedding planning, interior design, boutique businesses.

---

### 8. Tech Innovation
*Bold and modern, high-contrast tech aesthetic.*

**Color Palette**:
- Electric Blue `#0066ff` — vibrant primary accent
- Neon Cyan `#00ffff` — bright highlight
- Dark Gray `#1e1e1e` — deep backgrounds
- White `#ffffff` — clean text, contrast

**Typography**:
- Headers: DejaVu Sans Bold
- Body: DejaVu Sans

**Best for**: Tech startups, software launches, AI/ML presentations, digital transformation, innovation showcases.

---

### 9. Botanical Garden
*Fresh and organic, vibrant garden-inspired.*

**Color Palette**:
- Fern Green `#4a7c59` — rich natural green
- Marigold `#f9a620` — bright floral accent
- Terracotta `#b7472a` — earthy warm tone
- Cream `#f5f3ed` — soft neutral backgrounds

**Typography**:
- Headers: DejaVu Serif Bold
- Body: DejaVu Sans

**Best for**: Garden centers, food presentations, farm-to-table, botanical brands, natural products.

---

### 10. Midnight Galaxy
*Dramatic and cosmic, deep purples and mystical tones.*

**Color Palette**:
- Deep Purple `#2b1e3e` — rich dark base
- Cosmic Blue `#4a4e8f` — mystical mid-tone
- Lavender `#a490c2` — soft accent
- Silver `#e6e6fa` — light highlights, text

**Typography**:
- Headers: FreeSans Bold
- Body: FreeSans

**Best for**: Entertainment, gaming, nightlife, luxury brands, creative agencies.

---

## Theme Selection Decision Logic

Use this decision tree when choosing a theme for a user:

```
Does user specify brand colors?
  → YES: Design from scratch using their palette
  → NO: Continue...

What is the presentation about?
  Corporate/Finance/Trust  → Ocean Depths (1) or Modern Minimalist (4)
  Creative/Marketing       → Sunset Boulevard (2) or Botanical Garden (9)
  Environment/Wellness     → Forest Canopy (3) or Botanical Garden (9)
  Data/Tech/Software       → Modern Minimalist (4) or Tech Innovation (8)
  Hospitality/Food         → Golden Hour (5) or Botanical Garden (9)
  Healthcare/Science       → Arctic Frost (6) or Modern Minimalist (4)
  Fashion/Lifestyle        → Desert Rose (7) or Sunset Boulevard (2)
  Gaming/Entertainment     → Midnight Galaxy (10) or Tech Innovation (8)
  Academic/Research        → Modern Minimalist (4) or Ocean Depths (1)
```

When unsure, ask: "What mood should the presentation convey?" Then map:
- Professional/trustworthy → Ocean Depths or Modern Minimalist
- Warm/inviting → Golden Hour or Sunset Boulevard
- Energetic/innovative → Tech Innovation or Sunset Boulevard
- Natural/sustainable → Forest Canopy or Botanical Garden
- Dramatic/premium → Midnight Galaxy or Burgundy Luxury

---

## Applying a Theme Consistently

After selecting a theme, apply it across all slides:

### HTML/CSS Artifacts

```css
/* Example: Ocean Depths */
:root {
  --color-primary: #1a2332;
  --color-accent: #2d8b8b;
  --color-accent-light: #a8dadc;
  --color-background: #f1faee;
  --font-heading: 'DejaVu Sans', Arial, sans-serif;
  --font-body: 'DejaVu Sans', Arial, sans-serif;
}

h1, h2, h3 {
  font-family: var(--font-heading);
  font-weight: bold;
  color: var(--color-primary);
}

body {
  font-family: var(--font-body);
  color: var(--color-primary);
  background-color: var(--color-background);
}

.accent { color: var(--color-accent); }
.highlight { background-color: var(--color-accent-light); }
```

### PowerPoint / PPTX Artifacts

When applying via html2pptx or direct PPTX editing:
- Background: use the theme's background color (Cream, Ivory, White variant)
- Title text: use the primary dark color, bold
- Body text: use the primary dark color, regular weight
- Accent shapes/bars: use the accent color
- Secondary elements: use the accent-light color
- Ensure all text meets 4.5:1 contrast ratio minimum

### LaTeX / Beamer

```latex
% Example: Ocean Depths in Beamer
\definecolor{primary}{HTML}{1a2332}
\definecolor{accent}{HTML}{2d8b8b}
\definecolor{accentlight}{HTML}{a8dadc}
\definecolor{background}{HTML}{f1faee}

\setbeamercolor{normal text}{fg=primary, bg=background}
\setbeamercolor{frametitle}{fg=background, bg=primary}
\setbeamercolor{structure}{fg=accent}
\setbeamercolor{alerted text}{fg=accent}
```

---

## Creating a Custom Theme

When none of the 10 built-in themes fits, generate a custom theme following this structure:

```markdown
# [Theme Name]
[One-sentence description]

## Color Palette
- **[Role]**: `#XXXXXX` — [description and use]
- **[Role]**: `#XXXXXX` — [description and use]
- **[Role]**: `#XXXXXX` — [description and use]
- **[Role]**: `#XXXXXX` — [description and use]

## Typography
- **Headers**: [Font name] Bold
- **Body Text**: [Font name]

## Best Used For
[List of content types or industries]
```

**Custom theme guidelines**:
1. Give it a descriptive name (like the built-in themes)
2. Use 4 colors: dark (primary/text), mid (accent), light (secondary accent), neutral (background)
3. Verify contrast: dark-on-neutral must meet 4.5:1; accent-on-neutral must meet 3:1
4. Choose font pairings: Serif header + Sans body for editorial feel; Sans + Sans for modern/tech
5. Show the theme for user review before applying
6. Apply consistently across all slides/elements after approval

**Color contrast quick check**:
- `#1a2332` on `#f1faee` = 13.5:1 (excellent)
- `#0066ff` on `#1e1e1e` = 6.8:1 (good)
- `#f4a900` on `#4a403a` = 5.2:1 (passes AA)
- Rule: If in doubt, darken the dark or lighten the light

---

## Application Checklist

Before finalizing a themed artifact:

- [ ] Background color applied consistently to all slides/sections
- [ ] All heading text uses primary dark color (or theme's light color on dark backgrounds)
- [ ] All accent shapes/bars/borders use the accent color
- [ ] Font family applied to all text elements (not mixed with defaults)
- [ ] Bold applied to all headings
- [ ] Contrast verified: text on background meets 4.5:1 minimum
- [ ] No orphaned default colors (check for PowerPoint blue `#4472C4`, Word black `#000000` on dark bg)
- [ ] Visual consistency across all slides (same color roles throughout)
