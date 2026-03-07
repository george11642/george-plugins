# Accessibility and Inclusive Design for Presentations

Presentations that exclude audience members with disabilities lose impact and credibility. This reference covers WCAG standards, color-blind-safe design, typography accessibility, and cognitive load reduction.

---

## WCAG Standards for Presentations

### Contrast Ratios

WCAG defines three levels of compliance for text contrast:

| Level | Ratio | What it covers |
|-------|-------|----------------|
| AA minimum | 4.5:1 | Normal text (under 18pt, or under 14pt bold) |
| AA large text | 3:1 | Large text (18pt+ normal, or 14pt+ bold) |
| AAA preferred | 7:1 | All text — strongly recommended for presentations |

**For presentations, target 7:1 on all body text.** Slides are often viewed from a distance, on projectors with reduced contrast, or on low-quality screens.

**Common failures:**
- Light gray text on white background (#999 on #FFF = 2.85:1 — FAILS AA)
- White text on medium blue (#FFF on #4A90D9 = 3.0:1 — FAILS for small text)
- Yellow text on white (nearly always fails — yellow is low contrast)
- Light text on photo backgrounds (test every hero image zone)

**Checking contrast:**
```
# Command-line check (node)
npx contrast-ratio "#1565C0" "#FFFFFF"

# Python check
def contrast_ratio(hex1, hex2):
    def luminance(hex_c):
        hex_c = hex_c.lstrip('#')
        r, g, b = [int(hex_c[i:i+2], 16) / 255 for i in (0, 2, 4)]
        def linearize(c):
            return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
        r, g, b = linearize(r), linearize(g), linearize(b)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    l1 = luminance(hex1)
    l2 = luminance(hex2)
    lighter, darker = max(l1, l2), min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
```

### Color as the Only Indicator — Never

WCAG 1.4.1: Color must never be the sole means of conveying information.

**Fails:**
- "Red bars = bad performance, green bars = good performance" (color only)
- "The highlighted text shows the key finding" (if highlight is only color)
- Traffic-light status indicators with no text/icon

**Fixed versions:**
- Add text labels: "Below target" / "On target" alongside colors
- Add icons: warning triangle for bad, checkmark for good
- Add patterns: stripes for negative bars, solid for positive
- Add shape: circle = active, square = inactive (not just color)

### Font Size Minimums

| Text type | Minimum | Recommended |
|-----------|---------|-------------|
| Body text | 18pt | 24pt |
| Caption/note text | 14pt | 18pt |
| Chart axis labels | 14pt | 16pt |
| Chart data labels | 14pt | 16pt |
| Footer/reference text | 10pt | 12pt |

Never go below 10pt in any slide element. If content doesn't fit at 14pt+, the slide has too much content.

### Alt Text Requirement

Every diagram, chart, photo, and infographic needs alt text describing:
1. What it shows
2. The key insight or message

**python-pptx alt text:**
```python
pic = slide.shapes.add_picture(...)
pic._element.nvPicPr.cNvPr.set('descr',
    'Bar chart showing Q3 revenue by region. Northeast leads with $4.2M, '
    '42% above the next highest region.')
```

**HTML slide alt text:**
```html
<img src="chart.png"
     alt="Bar chart: Northeast $4.2M, Midwest $2.9M, South $2.1M, West $1.8M.
          Northeast leads by 45%.">
```

---

## Color-Blind Safe Palettes

Approximately 8% of men and 0.5% of women have some form of color vision deficiency.

### Types of Color Vision Deficiency

| Type | Prevalence | Confusion |
|------|-----------|-----------|
| Deuteranopia | 1 in 12 men | Red-green (most common) |
| Protanopia | 1 in 100 men | Red-green (reds appear dark) |
| Tritanopia | 1 in 10,000 | Blue-yellow (rare) |
| Achromatopsia | Very rare | Complete color blindness |

### Deuteranopia-Safe Color Pairs

These pairs are distinguishable for deuteranopia and protanopia:

```
SAFE:   Blue  (#1565C0) vs. Orange (#FF6B35)
SAFE:   Blue  (#1565C0) vs. Yellow (#FFD600)
SAFE:   Teal  (#00897B) vs. Orange (#FF6B35)
SAFE:   Navy  (#1A237E) vs. Gold   (#FFC107)
SAFE:   Black (#1A1A1A) vs. White  (#FFFFFF)

UNSAFE: Red   (#E53935) vs. Green  (#43A047)  ← classic fail
UNSAFE: Red   (#E53935) vs. Brown  (#795548)
UNSAFE: Green (#43A047) vs. Yellow (#FFD600)  ← often confused
```

### Okabe-Ito Colorblind-Safe Palette

The Okabe-Ito palette is the gold standard for scientific and data presentations. All 8 colors are distinguishable across all major color vision deficiencies.

```
#000000  Black
#E69F00  Orange
#56B4E9  Sky Blue
#009E73  Bluish Green
#F0E442  Yellow
#0072B2  Blue
#D55E00  Vermillion
#CC79A7  Reddish Purple
```

**python-pptx application (chart series):**
```python
OKABE_ITO = [
    '#E69F00', '#56B4E9', '#009E73',
    '#F0E442', '#0072B2', '#D55E00', '#CC79A7'
]

from pptx.dml.color import RGBColor

def hex_to_rgb(h):
    h = h.lstrip('#')
    return RGBColor(int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))

for i, series in enumerate(chart.series):
    series.format.fill.solid()
    series.format.fill.fore_color.rgb = hex_to_rgb(OKABE_ITO[i % len(OKABE_ITO)])
```

### Testing Tools

- **Color Oracle** (free desktop app, Mac/Windows/Linux): simulates deuteranopia, protanopia, tritanopia on your entire screen in real time
- **Coblis** (coblis.wickline.org): upload image, simulate all deficiency types
- **Sim Daltonism** (Mac): floating window overlay
- **Adobe Color** (color.adobe.com/create/color-accessibility): checks palette combinations
- **Chrome DevTools**: Rendering panel > Emulate vision deficiencies

---

## Typography for Accessibility

### Recommended Font Families

**Sans-serif (recommended for most presentations):**
- **Inter** — excellent legibility at all sizes; highly accessible
- **Source Sans Pro** — open-source; excellent readability
- **IBM Plex Sans** — strong technical/data presentation presence
- **Noto Sans** — comprehensive Unicode support; multilingual presentations

**Monospace for data/code:**
- **JetBrains Mono** — clearest for code display
- **Fira Code** — great ligature support
- **IBM Plex Mono** — pairs well with IBM Plex Sans

### Dyslexia-Friendly Options

For educational, public health, or any presentation likely to include audience members with dyslexia:
- **Atkinson Hyperlegible** — designed by Braille Institute; exceptional for low vision
- **OpenDyslexic** — exaggerated letter bottoms help with orientation confusion

### What to Avoid

| Practice | Problem | Fix |
|----------|---------|-----|
| All-caps body text | 30% harder to read than mixed case | Title case or sentence case for body |
| Thin/light weights (100, 200, 300) | Very low contrast when projected | Use 400 minimum for body; 700 for emphasis |
| Heavy italics for multiple lines | Slant increases visual effort | Use italics for single words only |
| Justified text alignment | Uneven word spacing creates "rivers" | Left-align all body text |
| Line length > 70 chars | Eye tracking fatigue | Max 60-70 chars per line |
| Line height < 1.4× | Crowded lines, hard tracking | 1.5× line height for body text |

### Font Size Accessibility CSS

```css
/* Accessible base sizes */
:root {
  --font-title:    48px;   /* 36pt minimum; 48pt recommended */
  --font-subtitle: 32px;   /* 24pt minimum */
  --font-body:     24px;   /* 18pt minimum; 24pt recommended */
  --font-caption:  18px;   /* 14pt minimum */
  --font-note:     14px;   /* 10pt absolute minimum */
  --line-height:   1.5;
  --letter-spacing: 0.01em;
}

body { font-family: 'Inter', sans-serif; line-height: var(--line-height); }
h1   { font-size: var(--font-title); font-weight: 700; }
p    { font-size: var(--font-body); letter-spacing: var(--letter-spacing); }
```

---

## Chart Accessibility

### All Data Directly Labeled

Never use legend-only labeling. Add direct labels to every data point or series.

**Bad:** Chart with a legend in the corner mapping colors to series names.

**Good:** Each bar/line labeled directly with its name AND value.

```python
# python-pptx — enable data labels
from pptx.enum.chart import XL_LABEL_POSITION

plot = chart.plots[0]
plot.has_data_labels = True
data_labels = plot.data_labels
data_labels.show_value = True
data_labels.show_series_name = True
data_labels.position = XL_LABEL_POSITION.OUTSIDE_END
```

### Pattern Fills in Addition to Colors

Add distinguishable fill patterns so charts are readable in grayscale and for color-blind viewers.

**python-pptx pattern fills:**
```python
from pptx.enum.dml import MSO_PATTERN

PATTERNS = [
    MSO_PATTERN.PERCENT_50,      # medium dots
    MSO_PATTERN.HORIZONTAL,      # horizontal lines
    MSO_PATTERN.DIAGONAL_BRICK,  # diagonal hatching
    MSO_PATTERN.LARGE_CHECKER_BOARD,
    MSO_PATTERN.WAVE,
]

for i, point in enumerate(series.points):
    point.format.fill.patterned()
    point.format.fill.pattern = PATTERNS[i % len(PATTERNS)]
    point.format.fill.fore_color.rgb = hex_to_rgb(OKABE_ITO[i])
    point.format.fill.back_color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
```

### Alt Text Templates by Chart Type

**Bar/Column chart:**
> "[Chart type] comparing [subject] across [categories]. [Highest category] leads with [value], [X]% above [comparison]. [Key trend or insight]."

**Line chart:**
> "Line chart showing [metric] over [time period]. [Subject] [increased/decreased] from [start value] to [end value], a [X]% [change]. [Notable peak/trough and when it occurred]."

**Pie/Donut chart:**
> "Donut chart showing [total/subject] composition. [Largest segment] accounts for [X]% ([value]). [Second largest] is [Y]%. Remaining [Z]% split among [other categories]."

**Scatter plot:**
> "Scatter plot of [X axis] vs [Y axis] for [N data points]. [Correlation description, e.g., strong positive correlation]. [Notable outliers or clusters]."

### Sufficient Internal Contrast

Chart elements need 3:1 contrast against their background:
- Bar fill against white background
- Line against white background
- Data point markers against plot area background
- Axis labels against plot area background

---

## Cognitive Accessibility

### White Space Reduces Cognitive Load

Rule: 20%+ intentional white space on every slide.

- Dense slides force audiences to choose what to read — they often give up
- White space signals "this is the important thing" when surrounding a key element
- Projection environments reduce apparent contrast; more space = more readable

**Density audit:**
```
Slide area: 10 × 7.5 = 75 sq inches
Content blocks (estimated):  < 60 sq inches (80% max)
White space target: 15+ sq inches (20%+)
```

### Consistent Layouts Enable Pattern Recognition

Once an audience learns your layout, they stop thinking about the layout and focus on content.

Rules:
- Title ALWAYS in the same position (top-left preferred)
- Body text ALWAYS in the same zone
- Visual ALWAYS in the same zone (right or bottom)
- Color assignments ALWAYS consistent (accent = emphasis, always)
- Never change the typeface mid-presentation
- Maximum 2 layout templates per presentation (standard + section-divider)

### One Key Message Per Slide

"One slide, one message" is an accessibility principle, not just a design rule. Audiences with cognitive differences, ADHD, or language processing challenges cannot parse multi-message slides.

Test: Can you write the slide's message in one sentence of 10 words or fewer?
- If yes: the slide is focused
- If no: split it into multiple slides

### Avoid Strobing and Flashing

WCAG 2.3.1: Content must not flash more than 3 times per second.

For animated presentations (Keynote, Reveal.js, HTML slides):
- Avoid rapid transitions (< 300ms)
- No auto-playing GIFs with fast cycles in presentation context
- Fade transitions are safest
- Warn audiences before any rapid animation sequences

---

## Testing Checklist

### Pre-Export Checks (every slide)

- [ ] All body text 18pt minimum (24pt recommended)
- [ ] All text passes 4.5:1 contrast (7:1 preferred)
- [ ] No color-only information (labels/icons added)
- [ ] Every chart has direct data labels (no legend-only)
- [ ] Every image/diagram has alt text
- [ ] Every chart has pattern fill in addition to color

### Zoom/Scale Checks

- [ ] Readable at 75% zoom (simulate distance viewing)
- [ ] Readable at 50% zoom (far back rows of a room)
- [ ] No text overflow at any zoom level

### Simulation Checks

- [ ] Visible and meaningful in grayscale (print test or Chrome > Print Preview)
- [ ] Pass deuteranopia simulation (Color Oracle or Coblis)
- [ ] Pass protanopia simulation
- [ ] Text remains readable at all simulated vision levels

### Interactive/Digital Checks (if applicable)

- [ ] All interactive elements keyboard-accessible (Tab key navigable)
- [ ] No keyboard traps
- [ ] Animation can be paused or skipped
- [ ] PDF export has tagged PDF structure (if exporting from PowerPoint: File > Export > Create PDF/XPS, check "Document structure tags")
