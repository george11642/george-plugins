# Styles Catalog: 50+ UI Styles

## Mainstream Styles

### Minimalism
- Clean lines, ample whitespace, limited color palette
- Typography-driven hierarchy, no unnecessary decoration
- Best for: portfolios, luxury brands, SaaS dashboards
- Key CSS: large padding, restrained palette (2-3 colors), generous line-height

### Flat Design
- No gradients, shadows, or textures; pure color blocks
- Bold colors, simple geometric shapes, clean icons
- Best for: mobile apps, government sites, utility tools
- Key CSS: solid backgrounds, no box-shadow, flat button styles

### Material Design
- Elevation via shadows, motion, bold colors, ripple effects
- Grid-based layout, floating action buttons, card-based UI
- Best for: Android apps, data-heavy dashboards, enterprise tools
- Key CSS: layered shadows, transition timing functions, rounded cards

### Glassmorphism
- Frosted glass effect with background blur and transparency
- Layered depth, subtle borders, vibrant or gradient backgrounds
- Best for: music apps, fintech, modern portfolios
- Key CSS: `backdrop-filter: blur(16px)`, `bg-white/10`, subtle `border-white/20`
- Light mode: use `bg-white/80` or higher opacity

### Neumorphism
- Soft, extruded elements using inner/outer shadows on matching background
- Monochromatic palette, subtle depth, tactile feel
- Best for: calculators, audio controls, settings panels
- Key CSS: dual box-shadow (light + dark), same bg color as parent

### Claymorphism
- 3D clay-like elements with rounded forms and playful shadows
- Bright pastels, thick borders, cartoon-like depth
- Best for: kids' apps, creative tools, playful landing pages
- Key CSS: inner shadow + outer shadow, border-radius 16-24px, pastel fills

### Brutalism
- Raw, unpolished aesthetics; exposed structure, monospace fonts
- High contrast, thick borders, intentional "ugliness"
- Best for: portfolios, art galleries, experimental sites
- Key CSS: thick solid borders, system/mono fonts, stark black/white

### Skeuomorphism
- Realistic textures mimicking physical objects (leather, wood, metal)
- Gradients, reflections, detailed shadows
- Best for: music production tools, vintage apps, novelty UIs
- Key CSS: complex gradients, texture backgrounds, detailed box-shadows

## Trending Styles

### Bento Grid
- Grid of mixed-size cards (inspired by Japanese bento boxes)
- Asymmetric layouts, varied content types per cell
- Best for: dashboards, feature showcases, landing pages
- Key CSS: CSS Grid with `grid-template-areas`, gap, varied `span`

### Aurora / Gradient Mesh
- Flowing, organic gradient backgrounds with multiple color stops
- Soft transitions, dreamy atmosphere, depth through color
- Best for: creative agencies, music platforms, wellness apps
- Key CSS: radial/conic gradients, animated gradient positions, blur overlays

### Dark Mode
- Dark backgrounds (#0A0A0A to #1A1A1A), light text
- Reduced eye strain, OLED-friendly, premium feel
- Best for: dev tools, media apps, gaming, any modern app
- Key CSS: dark surface colors, dimmed secondary text, adjusted shadows

### Retro / Y2K
- Nostalgic 90s/2000s web aesthetics, pixel fonts, bold colors
- Animated GIFs, chunky borders, playful chaos
- Best for: creative portfolios, gaming, entertainment
- Key CSS: pixel borders, retro color palettes, bitmap fonts

### Swiss / International Style
- Grid precision, sans-serif typography, asymmetric balance
- Mathematical proportions, limited color, strong hierarchy
- Best for: corporate sites, editorial, data visualization
- Key CSS: strict grid systems, Helvetica/Inter, precise spacing

### Neobrutalism
- Flat colors + thick black borders + strong shadows
- Playful yet bold, high contrast, intentional imperfection
- Best for: startups, creative tools, portfolios
- Key CSS: `border: 3px solid black`, `box-shadow: 4px 4px 0px black`, bright fills

### Organic / Biomorphic
- Soft, rounded shapes inspired by nature; blob-like elements
- Earthy tones, flowing lines, asymmetric curves
- Best for: wellness, eco brands, food/health apps
- Key CSS: SVG blobs, border-radius with different corners, organic color palette

### Maximalism
- Bold patterns, mixed media, layered textures, more is more
- Clashing colors, multiple fonts, visual density
- Best for: fashion, music, art, entertainment
- Key CSS: layered backgrounds, mixed blend modes, multiple font families

### Cyberpunk / Neon
- Neon colors on dark backgrounds, glitch effects, futuristic
- Cyan, magenta, electric purple; scanline textures
- Best for: gaming, nightlife, tech/hacker aesthetic
- Key CSS: neon text-shadow, dark bg, glitch animations, monospace fonts

### Mono / Monochromatic
- Single hue with varying saturation and lightness
- Sophisticated, cohesive, elegant simplicity
- Best for: luxury brands, photography, editorial
- Key CSS: HSL color system with single hue, varied saturation/lightness

## Specialized Styles

### Editorial / Magazine
- Large typography, multi-column layouts, pull quotes
- Dramatic image usage, sophisticated grid systems
- Best for: blogs, news sites, content-heavy platforms

### Dashboard / Data-Heavy
- Dense information layout, consistent card system, filters
- Status indicators, charts, tables with row actions
- Best for: admin panels, analytics, monitoring tools

### E-commerce
- Product grid, quick-view cards, prominent CTAs
- Trust signals, reviews, comparison features
- Best for: online stores, marketplaces, product catalogs

### SaaS / Product
- Feature sections, pricing tables, testimonials, social proof
- Hero with CTA, demo/screenshot, integration logos
- Best for: software products, API services, platforms

### Portfolio / Creative
- Large hero images, project grids, case study layouts
- Minimal navigation, immersive scrolling, typography-forward
- Best for: designers, photographers, agencies

## Style Selection Guide

| Product Type | Recommended Styles | Avoid |
|---|---|---|
| SaaS B2B | Minimalism, Material, Swiss | Brutalism, Cyberpunk |
| E-commerce | Flat, Bento Grid, Material | Neumorphism, Brutalism |
| Portfolio | Minimalism, Brutalism, Editorial | Material, Dashboard |
| Healthcare | Organic, Minimalism, Flat | Cyberpunk, Maximalism |
| Fintech | Swiss, Minimalism, Dark Mode | Claymorphism, Retro |
| Gaming | Cyberpunk, Dark Mode, Maximalism | Swiss, Minimalism |
| Kids/Education | Claymorphism, Flat, Organic | Brutalism, Swiss |
| Luxury | Mono, Minimalism, Editorial | Flat, Neobrutalism |

## Anti-Patterns (AI Slop)
- Excessive centered layouts with purple gradients
- Uniform rounded corners on everything
- Inter font everywhere with no typographic hierarchy
- Emojis as icons (use SVG: Heroicons, Lucide, Simple Icons)
- Scale transforms on hover that shift layout
- `bg-white/10` glass cards in light mode (invisible)
- Gray-400 text on white background (unreadable)
