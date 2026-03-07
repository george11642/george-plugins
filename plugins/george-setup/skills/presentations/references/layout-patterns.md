# Layout Patterns Reference

A comprehensive guide to geometric, typographic, and structural layout patterns for modern presentations.

---

## Geometric Patterns

### Diagonal Section Dividers

Diagonal dividers create energy and movement across a slide. Use sparingly — one per slide maximum.

**CSS (HTML slide):**
```css
.diagonal-divider {
  clip-path: polygon(0 0, 100% 0, 100% 85%, 0 100%);
  background: #1a237e;
  padding: 2rem 2rem 4rem 2rem;
}
/* Reverse diagonal */
.diagonal-divider-reverse {
  clip-path: polygon(0 0, 100% 15%, 100% 100%, 0 100%);
}
```

**OOXML (python-pptx) — diagonal line shape:**
```python
from pptx.util import Pt, Emu
from pptx.enum.shapes import MSO_SHAPE_TYPE
# Add a diagonal rule line
line = slide.shapes.add_connector(
    pp.enum.shapes.PP_CONNECTOR.STRAIGHT,
    Emu(0), Emu(914400),          # left, top (1 inch down)
    Emu(9144000), Emu(0)          # right, top (spans full width)
)
line.line.color.rgb = RGBColor(0x1A, 0x23, 0x7E)
line.line.width = Pt(2)
```

### Asymmetric Column Splits

Break the 50/50 column habit. Asymmetric splits create visual hierarchy immediately.

| Split | Use case | Rule |
|-------|----------|------|
| 30/70 | Narrow label + wide content | Label column uses accent color background |
| 40/60 | Image + text | Image left, text right |
| 25/75 | Timeline marker + detail | Number/date in narrow col, prose in wide |
| 70/30 | Statement + supporting stat | Big claim left, evidence number right |

**python-pptx implementation (40/60 split):**
```python
from pptx.util import Inches, Pt

SLIDE_W = Inches(13.33)
SLIDE_H = Inches(7.5)

# Left column: 40% width
left_col = slide.shapes.add_textbox(
    Inches(0.3), Inches(1.0),
    SLIDE_W * 0.4 - Inches(0.6), SLIDE_H - Inches(1.5)
)
# Right column: 60% width
right_col = slide.shapes.add_textbox(
    SLIDE_W * 0.4, Inches(1.0),
    SLIDE_W * 0.6 - Inches(0.3), SLIDE_H - Inches(1.5)
)
```

### Rotated Text Headers

Rotate section labels 90 degrees for a modern editorial feel. Best on left or right margin.

**CSS:**
```css
.rotated-header {
  writing-mode: vertical-rl;
  text-orientation: mixed;
  transform: rotate(180deg);
  font-size: 11px;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: #666;
}
```

**OOXML XML snippet (a:txBody rotation):**
```xml
<p:sp>
  <p:spPr>
    <a:xfrm rot="-5400000">  <!-- -90 degrees in 60000ths of a degree -->
      <a:off x="457200" y="914400"/>
      <a:ext cx="685800" cy="3657600"/>
    </a:xfrm>
  </p:spPr>
</p:sp>
```

### Circular and Hexagonal Image Frames

Rounded frames soften technical content and create approachable, modern aesthetics.

**CSS circle frame:**
```css
.circle-frame {
  width: 280px;
  height: 280px;
  border-radius: 50%;
  overflow: hidden;
  border: 4px solid #ffffff;
  box-shadow: 0 4px 20px rgba(0,0,0,0.15);
}
.circle-frame img { width: 100%; height: 100%; object-fit: cover; }
```

**CSS hexagon frame:**
```css
.hex-frame {
  width: 200px;
  height: 230px;
  clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%);
  overflow: hidden;
}
```

**python-pptx circular crop:**
```python
from pptx.util import Inches
from pptx.oxml.ns import qn
from lxml import etree

pic = slide.shapes.add_picture("photo.jpg", Inches(1), Inches(1), Inches(3), Inches(3))
# Apply circular crop via XML
spPr = pic.shape._element.spPr
custGeom = etree.SubElement(spPr, qn('a:custGeom'))
# Use prstGeom ellipse instead:
spPr.remove(spPr.find(qn('a:prstGeom'))) if spPr.find(qn('a:prstGeom')) is not None else None
prstGeom = etree.SubElement(spPr, qn('a:prstGeom'))
prstGeom.set('prst', 'ellipse')
etree.SubElement(prstGeom, qn('a:avLst'))
```

### Triangular Accent Shapes

Small triangular accents add direction and energy without overwhelming content.

**CSS triangle (CSS border trick):**
```css
.triangle-accent {
  width: 0;
  height: 0;
  border-left: 20px solid transparent;
  border-right: 20px solid transparent;
  border-bottom: 35px solid #FF6B35;
}
.triangle-right {
  border-top: 20px solid transparent;
  border-bottom: 20px solid transparent;
  border-left: 35px solid #FF6B35;
}
```

**Overlapping shapes for depth (CSS z-index layering):**
```css
.shape-stack { position: relative; }
.shape-back {
  position: absolute;
  width: 200px; height: 200px;
  background: #e3f2fd;
  border-radius: 8px;
  transform: rotate(8deg);
  top: 10px; left: 10px;
}
.shape-front {
  position: relative;
  width: 200px; height: 200px;
  background: #1565c0;
  border-radius: 8px;
}
```

---

## Border and Frame Treatments

### Thick Single-Color Borders

A thick border on one side (left or bottom) anchors content without boxing it in.

```css
/* Left accent border — strongest visual anchor */
.left-border { border-left: 16px solid #FF6B35; padding-left: 1.5rem; }

/* Bottom accent — good under slide titles */
.bottom-border { border-bottom: 12px solid #1565c0; padding-bottom: 0.75rem; }

/* Top accent — use for callout boxes */
.top-border { border-top: 10px solid #00897b; padding-top: 0.75rem; }
```

**OOXML line format:**
```xml
<a:ln w="127000" cap="flat">  <!-- 10pt = 127000 EMUs -->
  <a:solidFill><a:srgbClr val="FF6B35"/></a:solidFill>
</a:ln>
```

Use 10-20pt (127000–254000 EMUs) for emphasis borders.

### Double-Line Borders

Two parallel lines create a refined, editorial look.

```css
.double-border {
  border: 3px solid #1a237e;
  outline: 6px solid #1a237e;
  outline-offset: 4px;
}
/* Alternative: box-shadow approach */
.double-shadow {
  box-shadow: 0 0 0 3px #1a237e, 0 0 0 7px #ffffff, 0 0 0 10px #1a237e;
}
```

### Corner Bracket Accents

Corner brackets frame content elegantly without full borders.

```css
.corner-bracket {
  position: relative;
  padding: 1.5rem;
}
.corner-bracket::before,
.corner-bracket::after {
  content: '';
  position: absolute;
  width: 20px; height: 20px;
}
.corner-bracket::before {
  top: 0; left: 0;
  border-top: 3px solid #1565c0;
  border-left: 3px solid #1565c0;
}
.corner-bracket::after {
  bottom: 0; right: 0;
  border-bottom: 3px solid #1565c0;
  border-right: 3px solid #1565c0;
}
```

### L-Shaped Borders

Top+left or bottom+right L-shapes give asymmetric, dynamic framing.

```css
.l-border-tl {
  border-top: 4px solid #FF6B35;
  border-left: 4px solid #FF6B35;
  padding: 1rem 1rem 0.5rem 1rem;
}
.l-border-br {
  border-bottom: 4px solid #FF6B35;
  border-right: 4px solid #FF6B35;
  padding: 0.5rem 1rem 1rem 1rem;
}
```

### Underline Accents Beneath Headers

```css
.underline-accent {
  display: inline-block;
  padding-bottom: 8px;
  border-bottom: 4px solid #FF6B35;
  margin-bottom: 1rem;
}
/* Gradient underline */
.gradient-underline {
  background: linear-gradient(to right, #FF6B35, #1565c0);
  background-size: 60% 4px;
  background-repeat: no-repeat;
  background-position: 0 100%;
  padding-bottom: 8px;
}
```

---

## Typography-First Layouts

### Extreme Size Contrast

Pair massive display type with micro-sized supporting text to create instant hierarchy.

```css
/* Rule: 6:1 to 8:1 ratio between title and body */
.display-title { font-size: 72px; font-weight: 900; line-height: 1.0; }
.support-detail { font-size: 11px; font-weight: 400; line-height: 1.6; }

/* Editorial pair: number + descriptor */
.stat-number { font-size: 120px; font-weight: 800; color: #1565c0; }
.stat-label  { font-size: 14px; text-transform: uppercase; letter-spacing: 0.2em; }
```

### All-Caps Headers with Wide Letter Spacing

```css
.section-header {
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.25em;
  color: #666;
  margin-bottom: 1.5rem;
}
```

### Numbered Sections in Oversized Display Type

```css
.section-number {
  font-size: 120px;
  font-weight: 900;
  color: #f0f4ff;     /* Very light — background layer */
  position: absolute;
  top: -20px;
  left: -10px;
  z-index: 0;
  line-height: 1;
}
.section-content { position: relative; z-index: 1; }
```

### Monospace for Data and Technical Content

```css
.data-value {
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 18px;
  background: #f5f5f5;
  padding: 0.2em 0.4em;
  border-radius: 3px;
}
```

### Outlined (Stroke) Text for Emphasis

```css
.outlined-text {
  -webkit-text-stroke: 2px #1565c0;
  color: transparent;
  font-size: 64px;
  font-weight: 900;
}
/* Mix filled and outlined for depth */
.outlined-mix span:nth-child(odd)  { color: #1565c0; }
.outlined-mix span:nth-child(even) { -webkit-text-stroke: 2px #1565c0; color: transparent; }
```

---

## Data and Chart Styling

### Monochrome with Single Accent Color

The "one accent" rule: chart bars are all light gray except the highlighted value, which uses the accent color.

```python
# python-pptx chart styling — single accent
from pptx.dml.color import RGBColor

BASE_COLOR   = RGBColor(0xCC, 0xCC, 0xCC)  # light gray
ACCENT_COLOR = RGBColor(0xFF, 0x6B, 0x35)  # orange accent

chart = slide.shapes[0].chart
series = chart.series[0]
for i, point in enumerate(series.points):
    fill = point.format.fill
    fill.solid()
    fill.fore_color.rgb = ACCENT_COLOR if i == highlight_index else BASE_COLOR
```

### Horizontal Bar Charts (Preferred over Vertical)

Horizontal bars are more readable in presentations because:
- Category labels fit naturally (no diagonal text)
- Audiences scan top-to-bottom
- Easier to compare across longer category names

```python
from pptx.chart.data import ChartData
from pptx.enum.chart import XL_CHART_TYPE

chart_data = ChartData()
chart_data.categories = ['Category A', 'Category B', 'Category C']
chart_data.add_series('Values', (42, 28, 73))

chart = slide.shapes.add_chart(
    XL_CHART_TYPE.BAR_CLUSTERED,  # BAR = horizontal
    left, top, width, height,
    chart_data
).chart
```

### Dot Plots Instead of Bar Charts

Use when showing distribution or comparison without implying continuous progression.

```html
<!-- HTML dot plot using CSS grid -->
<div class="dot-plot">
  <div class="dot-row" style="--value: 72">
    <span class="label">Group A</span>
    <div class="track"><div class="dot" style="left: calc(var(--value) * 1%)"></div></div>
    <span class="value">72%</span>
  </div>
</div>
<style>
.track { position: relative; height: 2px; background: #eee; flex: 1; }
.dot   { position: absolute; width: 16px; height: 16px; border-radius: 50%;
         background: #1565c0; top: -7px; transform: translateX(-50%); }
</style>
```

### Minimal/No Gridlines

```python
# Remove all gridlines
plot = chart.plots[0]
value_axis = chart.value_axis
value_axis.major_gridlines.format.line.fill.background()  # transparent
value_axis.has_minor_gridlines = False
```

### Oversized Key Metrics (100pt+)

For single-number slides, go massive:

```python
# python-pptx — 100pt+ metric display
from pptx.util import Pt, Inches
txBox = slide.shapes.add_textbox(Inches(1), Inches(1.5), Inches(11), Inches(3))
tf = txBox.text_frame
p = tf.paragraphs[0]
p.alignment = PP_ALIGN.CENTER
run = p.add_run()
run.text = "94%"
run.font.size = Pt(120)
run.font.bold = True
run.font.color.rgb = RGBColor(0x15, 0x65, 0xC0)
```

---

## Bento Grid Layouts (2026 Trend)

Bento grids divide the slide into modular rectangular tiles — inspired by Apple product pages and dashboard UIs. Each tile contains one piece of content: a metric, a quote, a chart, or an image.

### When to Use Bento Grids

- Summary slides consolidating multiple data points
- "Why us" or "key benefits" slides (3-6 benefits)
- Dashboard-style status overviews
- Product feature highlights

### 3x3 Grid Template (HTML)

```html
<div class="bento-grid">
  <!-- Row 1: wide tile + narrow tile -->
  <div class="tile tile-wide">
    <h3>Main Insight</h3>
    <p class="stat">94%</p>
    <p class="label">Satisfaction Rate</p>
  </div>
  <div class="tile tile-narrow accent">
    <p class="icon">+</p>
    <p class="metric">2.4×</p>
    <p class="label">ROI</p>
  </div>

  <!-- Row 2: three equal tiles -->
  <div class="tile">Chart</div>
  <div class="tile">Quote</div>
  <div class="tile">Image</div>
</div>

<style>
.bento-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  grid-template-rows: repeat(2, 1fr);
  gap: 16px;
  padding: 24px;
  height: 100%;
}
.tile {
  background: #f8f9fa;
  border-radius: 16px;
  padding: 24px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.tile.accent { background: #1565c0; color: white; }
.tile.dark   { background: #1a1a2e; color: white; }
.tile-wide   { grid-column: span 1; }
.stat  { font-size: 64px; font-weight: 900; line-height: 1; margin: 8px 0; }
.label { font-size: 13px; text-transform: uppercase; letter-spacing: 0.1em; opacity: 0.7; }
</style>
```

### 4x4 Variable-Size Bento (HTML)

```html
<div class="bento-4x4">
  <!-- Hero tile: spans 2 columns, 2 rows -->
  <div class="tile hero">Primary Visual / Chart</div>
  <!-- Metric tiles -->
  <div class="tile metric">47K <span>Users</span></div>
  <div class="tile metric accent">99.9% <span>Uptime</span></div>
  <!-- Wide tile: spans 2 columns -->
  <div class="tile wide">Supporting narrative text or quote</div>
  <!-- Image tile -->
  <div class="tile image"><img src="..."></div>
  <!-- Small tiles -->
  <div class="tile small">Tag A</div>
  <div class="tile small">Tag B</div>
</div>

<style>
.bento-4x4 {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  grid-template-rows: repeat(3, 1fr);
  gap: 12px;
  padding: 20px;
}
.tile.hero  { grid-column: span 2; grid-row: span 2; }
.tile.wide  { grid-column: span 2; }
.tile.metric { font-size: 36px; font-weight: 800; }
.tile.metric span { display: block; font-size: 12px; font-weight: 400; opacity: 0.6; }
</style>
```

### Importance Hierarchy Rules

- Largest tile = most important message (hero)
- Accent-colored tile = secondary emphasis
- Neutral/light tiles = supporting context
- Never more than 2 accent-colored tiles per bento grid
- Minimum tile size: 200×150px at standard slide dimensions

---

## Content Flow Patterns

### Z-Pattern

Natural eye movement: top-left → top-right → bottom-left → bottom-right. Use for slides where you want the audience to consume all four quadrants.

```
[ Title / Hook ]    [ Key Visual ]
[                              ]
[ Supporting Data ] [ Call to Action ]
```

Best for: Summary slides, before/after comparisons, 2x2 matrices.

### F-Pattern

Eyes scan horizontally at the top, then down the left side. Use for text-heavy slides (avoid if possible — use visual-first layouts instead).

```
[████████████████████████]
[████████████████]
[████████]
[████████████████]
[████]
```

Best for: Detailed reference slides, appendix slides.

### Single-Column Vertical Flow (Mobile/Vertical Slides)

For 9:16 vertical slides, force a single column:
```
[ Full-width title ]
[ Full-width visual ]
[ Supporting text ]
[ CTA button ]
```

---

## Background Treatments

### Solid Color Blocks (40-60% of Slide)

A colored block occupying 40-60% of the slide creates a modern split background without needing gradients.

```css
.split-background {
  background: linear-gradient(to right, #1565c0 55%, #ffffff 55%);
}
/* Or using grid for precise control */
.split-grid {
  display: grid;
  grid-template-columns: 55% 45%;
}
.split-grid .left  { background: #1565c0; }
.split-grid .right { background: #ffffff; }
```

### Diagonal Split Background

```css
.diagonal-split {
  background: linear-gradient(135deg, #1565c0 50%, #ffffff 50%);
}
```

### Vertical Split Background

```css
.vertical-split {
  background: linear-gradient(to right, #1a237e 40%, #f5f5f5 40%);
}
```

### Negative Space as Design Element

White/empty space is not "wasted" space — it is the design. Aim for 20-40% intentional whitespace on every slide.

Rules:
- Never fill every corner — leave breathing room
- Use asymmetric whitespace: more space on one side creates tension and direction
- Whitespace around a single key number makes it feel monumental
- Run a "whitespace audit": if no quadrant is empty, the slide is too dense

---

## Quick Reference: Layout Decision Tree

```
What is the primary content?
├── Single number / metric     → Oversized metric layout (centered, 100pt+)
├── 2-4 key points             → Bento grid tiles
├── 1 image + 1 text block     → Asymmetric split (40/60 or 30/70)
├── Sequential steps           → Vertical stack or horizontal flow
├── Comparison (A vs B)        → Symmetrical 50/50 split
├── Data chart                 → Chart-dominant (70%), minimal text (30%)
└── Dense technical reference  → F-pattern with left-aligned headers
```
