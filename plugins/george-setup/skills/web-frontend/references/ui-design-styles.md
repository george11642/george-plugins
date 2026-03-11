# UI Design Styles Reference

Complete catalog of 67 UI design styles with specifications, colors, effects, and use cases. Sourced from ui-ux-pro-max.

## Style Selection by Product Type

| Product Type | Recommended Styles |
|---|---|
| SaaS / Dashboard | Minimalism, Flat Design, Bento Grid, Glassmorphism |
| E-commerce | Vibrant & Block-based, Aurora UI, Motion-Driven |
| E-commerce Luxury | Liquid Glass, Glassmorphism, 3D & Hyperrealism |
| Portfolio / Creative | Brutalism, Motion-Driven, Aurora UI |
| Healthcare / Finance | Minimalism, Accessible & Ethical, Trust & Authority |
| Beauty / Wellness | Soft UI Evolution, Neumorphism, Glassmorphism |
| Gaming | 3D & Hyperrealism, Retro-Futurism, Cyberpunk UI |
| AI / Chatbot | AI-Native UI, Minimalism, Zero Interface |
| Government / Public | Accessible & Ethical, Minimalism |
| Fintech / Crypto | Glassmorphism, Dark Mode (OLED), Cyberpunk UI |

## General Styles

### 1. Minimalism & Swiss Style
- **Colors**: Monochromatic, Black #000000, White #FFFFFF, Neutral accents (Beige #F5F1E8, Grey #808080)
- **Effects**: Subtle hover (200-250ms), smooth transitions, sharp shadows, clear type hierarchy
- **Best For**: Enterprise apps, dashboards, documentation, SaaS, professional tools
- **Don't Use For**: Creative portfolios, entertainment, playful brands
- **Light/Dark**: Both full | **Performance**: Excellent | **Accessibility**: WCAG AAA | **Complexity**: Low
- **CSS**: `display: grid, gap: 2rem, font-family: sans-serif, max-width: 1200px, clean borders`
- **Checklist**: Grid-based 12-16 cols, Typography hierarchy clear, No unnecessary decorations, WCAG AAA verified, Mobile responsive
- **Variables**: `--spacing: 2rem, --border-radius: 0px, --font-weight: 400-700, --shadow: none, --accent-color: single primary`

### 2. Glassmorphism
- **Colors**: Translucent white/dark overlays, Vibrant background gradients, Blur effects
- **Effects**: `backdrop-filter: blur(10-20px)`, frosted glass, layered transparency, light refraction
- **Best For**: SaaS, fintech, modern dashboards, landing pages
- **Don't Use For**: Text-heavy sites, low-end devices, accessibility-critical
- **Light/Dark**: Both | **Performance**: Moderate (blur cost) | **Accessibility**: Check contrast | **Complexity**: Medium
- **CSS**: `backdrop-filter: blur(16px), background: rgba(255,255,255,0.1), border: 1px solid rgba(255,255,255,0.2)`

### 3. Flat Design
- **Colors**: Bright, solid colors, no gradients, strong contrast
- **Effects**: Minimal — clean transitions, no 3D effects
- **Best For**: Mobile apps, dashboards, any content-first interface
- **Light/Dark**: Both | **Performance**: Excellent | **Accessibility**: WCAG AA | **Complexity**: Low

### 4. Neumorphism (Soft UI)
- **Colors**: Same as background with dual shadows (light + dark)
- **Effects**: `box-shadow: 8px 8px 16px #d1d1d1, -8px -8px 16px #ffffff`, soft press states
- **Best For**: Calculator apps, music players, toggles, wellness apps
- **Don't Use For**: Text-heavy, complex forms, accessibility-critical
- **Accessibility**: Poor contrast — use sparingly

### 5. Brutalism
- **Colors**: High contrast, limited palette, raw colors
- **Effects**: Harsh borders, raw typography, intentional "ugliness", no smooth transitions
- **Best For**: Creative agencies, artist portfolios, experimental projects
- **Don't Use For**: Enterprise, healthcare, finance
- **Complexity**: Medium — requires intentional design decisions

### 6. Claymorphism
- **Colors**: Pastel backgrounds, soft inner shadows, rounded shapes
- **Effects**: Inner shadows, puffed appearance, 3D-like without being skeuomorphic
- **Best For**: Educational apps, children's products, friendly SaaS, wellness
- **Light/Dark**: Light preferred | **Performance**: Good | **Complexity**: Medium

### 7. Aurora UI
- **Colors**: Gradient backgrounds with aurora/northern lights feel, multi-color blends
- **Effects**: Flowing color transitions, ambient backgrounds, subtle animation
- **Best For**: Creative brands, landing pages, modern SaaS
- **Performance**: Moderate | **Complexity**: Medium

### 8. Dark Mode (OLED)
- **Colors**: True black #000000 bg, high contrast text #F8FAFC, vibrant accents
- **Effects**: Glow accents, subtle borders, reduced eye strain
- **Best For**: Media apps, developer tools, gaming, fintech dashboards
- **CSS**: `background: #000000, color: #F8FAFC, border: 1px solid rgba(255,255,255,0.1)`

### 9. Vibrant & Block-based
- **Colors**: Bold, saturated color blocks, high contrast combinations
- **Effects**: Card hover lift, scale effects, smooth transitions
- **Best For**: E-commerce, social media, subscription services, marketing
- **Performance**: Excellent | **Accessibility**: Good with contrast check

### 10. Motion-Driven
- **Colors**: Any palette — motion IS the style
- **Effects**: Scroll-triggered animations, parallax, page transitions, micro-interactions
- **Best For**: Portfolios, agencies, product launches, storytelling
- **Don't Use For**: Accessibility-critical, data-heavy dashboards
- **Performance**: Moderate to Poor | **Accessibility**: Must respect prefers-reduced-motion

## Specialized Styles

### 11. Neubrutalism
- **Colors**: #FFEB3B Yellow, #FF5252 Red, #2196F3 Blue, #000000 Black borders
- **Effects**: `box-shadow: 4px 4px 0 #000, border: 3px solid #000`, no gradients, sharp corners
- **Best For**: Gen Z brands, startups, Figma/Notion-style apps
- **Variables**: `--border-width: 3px, --shadow-offset: 4px, --shadow-color: #000`

### 12. Bento Box Grid
- **Colors**: Neutral base + brand accent, #F5F5F5 cards
- **Effects**: `grid-template` with varied spans, rounded-xl (16px), hover scale (1.02)
- **Best For**: Dashboards, Apple-style marketing, feature showcases
- **CSS**: `display: grid, grid-template-columns: repeat(4, 1fr), gap: 16px, border-radius: 24px`
- **Variables**: `--grid-gap: 16px, --card-radius: 24px, --card-bg: #FFFFFF, --page-bg: #F5F5F7`

### 13. AI-Native UI
- **Colors**: Neutral + AI Purple #6366F1, Success #10B981, Background #F5F5F5
- **Effects**: Typing indicators (3-dot pulse), streaming text, context cards, smooth reveals
- **Best For**: AI products, chatbots, voice assistants, copilots
- **CSS**: Chat bubble layout (flex-direction: column), sticky bottom input, context cards
- **Variables**: `--ai-accent: #6366F1, --user-bubble-bg: #E0E7FF, --ai-bubble-bg: #F9FAFB`

### 14. Cyberpunk UI
- **Colors**: #00FF00 Matrix Green, #FF00FF Magenta, #00FFFF Cyan, #0D0D0D Dark
- **Effects**: Neon glow (text-shadow), glitch animations (skew/offset), scanlines overlay, terminal fonts
- **Best For**: Gaming, crypto, sci-fi, developer tools
- **Dark Mode Only** | **Accessibility**: Limited

### 15. Organic Biophilic
- **Colors**: #228B22 Forest Green, #8B4513 Earth Brown, #87CEEB Sky Blue, #F5F5DC Beige
- **Effects**: Rounded corners (16-24px), organic curves, natural shadows, flowing SVG shapes
- **Best For**: Wellness, sustainability, eco products, health apps

### 16. Exaggerated Minimalism
- **Colors**: #000000 Black, #FFFFFF White, single vibrant accent only
- **Effects**: `font-size: clamp(3rem, 10vw, 12rem), font-weight: 900, letter-spacing: -0.05em`
- **Best For**: Fashion, architecture, portfolios, agency landing pages
- **Variables**: `--type-giant: clamp(3rem, 10vw, 12rem), --spacing-huge: 8rem`

### 17. Kinetic Typography
- **Effects**: Animated text, scroll-triggered reveals, typing effects, morphing, gradient text fills
- **Best For**: Hero sections, marketing, video platforms, storytelling
- **Accessibility**: Poor (motion) — must respect prefers-reduced-motion
- **Libraries**: GSAP 10/10, Framer Motion 10/10

### 18. Spatial UI (VisionOS)
- **Colors**: Frosted Glass 15-30% opacity, System White, vibrant active states
- **Effects**: `backdrop-filter: blur(40px) saturate(180%)`, depth layers, gaze-hover
- **Best For**: Spatial computing, AR/VR, immersive media
- **CSS**: `background: rgba(255,255,255,0.2), border-radius: 24px, box-shadow: 0 8px 32px rgba(0,0,0,0.1)`

### 19. E-Ink / Paper
- **Colors**: Off-White #FDFBF7, Ink Black #1A1A1A, Highlighter Yellow accent
- **Effects**: No animations, instant transitions, grain/noise texture, sharp text
- **Best For**: Reading apps, digital newspapers, minimal journals, distraction-free writing
- **Accessibility**: WCAG AAA | **Performance**: Excellent

### 20. Y2K Aesthetic
- **Colors**: #FF69B4 Hot Pink, #00FFFF Cyan, #C0C0C0 Silver, #9400D3 Purple
- **Effects**: Metallic gradients, glossy buttons, 3D chrome, glow animations, bubble shapes
- **Best For**: Fashion, music, Gen Z brands, nostalgia marketing

### 21. Memphis Design (80s Postmodern)
- **Colors**: #FF71CE Hot Pink, #FFCE5C Yellow, #86CCCA Teal, #6A7BB4 Blue Purple
- **Effects**: `clip-path: polygon()`, repeating patterns, `transform: rotate()`, mix-blend-mode
- **Best For**: Creative agencies, music, youth brands, events

### 22. Vaporwave / Synthwave
- **Colors**: #FF71CE Pink, #01CDFE Cyan, #05FFA1 Mint, #B967FF Purple
- **Effects**: Sunset gradients, glitch effects, neon glow, retro grid, VHS scanlines
- **Best For**: Music, gaming, creative portfolios

### 23. Dimensional Layering
- **Effects**: z-index stacking, elevation shadows (4 levels), `transform: translateZ()`, backdrop-filter
- **Variables**: `--elevation-1: 0 1px 3px, --elevation-2: 0 4px 6px, --elevation-3: 0 10px 20px, --elevation-4: 0 20px 40px`

### 24. HUD / Sci-Fi FUI
- **Colors**: Neon Cyan #00FFFF, Holographic Blue #0080FF, Alert Red #FF0000
- **Effects**: 1px thin lines, neon glow, monospaced fonts, transparent backgrounds
- **Best For**: Sci-fi games, cybersecurity, immersive dashboards

### 25. Pixel Art / Retro Gaming
- **Effects**: `image-rendering: pixelated`, pixel fonts, box-shadow pixel borders, limited palette
- **Best For**: Indie games, retro tools, creative portfolios

### 26. Gen Z Chaos / Maximalism
- **Colors**: Clashing brights #FF00FF, #00FF00, #FFFF00, #0000FF
- **Effects**: Marquee scrolls, jitter, sticker layering, GIF overload, random placement
- **Best For**: Gen Z lifestyle, music artists, viral marketing
- **Accessibility**: Poor | **Performance**: Poor

### 27. Tactile Digital / Deformable UI
- **Effects**: Press deformation (scale 0.95 + squish), bounce-back (spring physics), haptic-like feedback
- **Libraries**: Framer Motion 10/10, React Spring 10/10, GSAP 10/10
- **Variables**: `--press-scale: 0.95, --bounce-duration: 400ms, --spring-stiffness: 300`

### 28. Anti-Polish / Raw Aesthetic
- **Colors**: Paper White #FAFAF8, Pencil Grey #4A4A4A, Marker Black #1A1A1A, Kraft Brown #C4A77D
- **Effects**: Hand-drawn elements, scanned textures, paper/pencil overlays, sketch marks
- **Best For**: Creative portfolios, artist sites, indie brands, authentic storytelling

### 29. Chromatic Aberration / RGB Split
- **Colors**: Offset RGB — Red #FF0000, Green #00FF00, Blue #0000FF
- **Effects**: `text-shadow: -2px 0 red, 2px 0 cyan`, glitch timing, scan lines
- **Best For**: Music, gaming, tech brands, creative portfolios

### 30. Vintage Analog / Retro Film
- **Colors**: Faded Cream #F5E6C8, Warm Sepia #D4A574, Muted Teal #4A7B7C
- **Effects**: `filter: sepia() contrast() saturate(0.8)`, film grain, light leaks, VHS tracking
- **Best For**: Photography portfolios, music/vinyl brands, vintage fashion

### 31. Gradient Mesh / Aurora Evolved
- **Colors**: Multi-stop gradients — Cyan #00FFFF, Magenta #FF00FF, Yellow #FFFF00
- **Effects**: Mesh gradients, flowing color transitions, holographic shimmer, prismatic

### 32. Editorial Grid / Magazine
- **Effects**: Asymmetric grid, pull quotes, drop caps, multi-column text, large imagery
- **CSS**: `column-count`, `::first-letter` for drop caps, named grid areas
- **Accessibility**: WCAG AAA | **Performance**: Excellent

### 33. Nature Distilled
- **Colors**: Terracotta #C67B5C, Sand Beige #D4C4A8, Warm Clay #B5651D, Soft Cream #F5F0E1, Olive Green #6B7B3C
- **Best For**: Wellness, sustainable products, artisan goods, spa/beauty

### 34. Interactive Cursor Design
- **Effects**: Custom cursor, morphing on hover, magnetic pull, trails, blend mode cursors
- **Best For**: Creative portfolios, interactive experiences, agency sites
- **No mobile** (no cursor)

### 35. Voice-First Multimodal
- **Colors**: Soft White #FAFAFA, Muted Blue #6B8FAF, Gentle Purple #9B8FBB
- **Effects**: Voice waveform, listening pulse, speaking animation, minimal visible UI
- **Best For**: Voice assistants, accessibility apps, hands-free tools

### 36. 3D Product Preview
- **Effects**: 360-degree rotation, drag-to-spin, pinch-to-zoom, AR preview, material switching
- **Libraries**: Three.js 10/10, model-viewer 10/10, Spline 9/10

### 37. Swiss Modernism 2.0
- **Colors**: #000000, #FFFFFF, single vibrant accent only
- **Effects**: Strict 12-column grid, mathematical spacing (8px base unit), Helvetica/Inter
- **Variables**: `--grid-columns: 12, --grid-gap: 1rem, --base-unit: 8px`

### 38. Biomimetic / Organic 2.0
- **Colors**: Cellular Pink #FF9999, Chlorophyll Green #00FF41, Bioluminescent Blue
- **Effects**: Breathing animations, fluid morphing, generative growth, physics-based movement

### 39. Predictive Analytics Dashboard
- **Effects**: Forecast lines (dashed), confidence intervals (shaded bands), anomaly highlights
- **Best For**: Forecasting dashboards, AI-powered analytics, budget planning

### 40. User Behavior Analytics Dashboard
- **Effects**: Funnel visualization, user flow diagrams (Sankey), conversion metrics, cohort tables

### 41. Financial Dashboard
- **Colors**: Profit green #22C55E, Loss red #EF4444, Trust dark blue #003366
- **Effects**: Number count-up animations, trend direction indicators, percentage change

### 42. Sales Intelligence Dashboard
- **Effects**: Pipeline funnel, deal cards (kanban), quota gauges, leaderboard, territory map

## CLI Search Tool

For detailed specifications on any style, use the search tool:

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keywords>" --domain style
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system -p "Project Name"
```
