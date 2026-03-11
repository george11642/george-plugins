# Mobile Presentations: Vertical / 9:16 Format Reference

Vertical slide design for mobile-first viewing, executive summary distribution, and social/video sharing.

---

## 9:16 Aspect Ratio Specifications

### Dimensions

| Format | Width | Height | Use case |
|--------|-------|--------|----------|
| **Standard HD** | 1080px | 1920px | Default for mobile/social |
| **PowerPoint pt** | 720pt | 1280pt | python-pptx standard |
| **Inch equivalent** | 7.5" | 13.33" | Google Slides custom size |
| **Low-res preview** | 540px | 960px | Fast preview generation |

The 9:16 ratio matches the aspect ratio of modern smartphones held vertically (portrait mode).

### When to Use 9:16

Use vertical slides for:
- Executive summaries distributed via messaging apps (Slack, WhatsApp, email)
- Social media sharing (LinkedIn carousels, Instagram stories, TikTok-style summaries)
- Mobile-first audiences (field teams, conferences where phones are primary device)
- Quick brief formats (5-10 slides max)
- Video export / animated summary reels

**2026 trend**: 9:16 is the fastest-growing presentation format. Mobile viewing of shared decks increased 340% from 2022 to 2025 (SlideEgg 2026 Design Trends Report).

### When NOT to Use 9:16

Do not use vertical slides for:
- Complex tables (insufficient horizontal space)
- Side-by-side comparisons
- Gantt charts or timelines with many columns
- Dense mathematical equations or formulas
- Flowcharts with many parallel paths
- Any content requiring landscape orientation

For these, use standard 16:9 and instruct viewers to rotate device.

---

## Design Principles for Vertical Slides

### The Single Focal Point Rule

Every 9:16 slide must have exactly ONE thing the viewer looks at first. With 1080×1920px of space, it is tempting to add multiple elements. Resist.

Priority hierarchy for vertical slides:
1. Title or key number (top third)
2. Primary visual — photo, chart, or diagram (middle third)
3. Supporting text or CTA (bottom third)

### Title Dominance

On vertical slides, titles should occupy 40-60% of the slide height. Use them as both information and visual design.

```css
.vertical-title {
  font-size: 72px;        /* Much larger than 16:9 equivalent */
  font-weight: 900;
  line-height: 1.1;
  padding: 60px 48px 40px 48px;
  min-height: 45%;
}
```

### Content Stacking Order

Standard stacking order for vertical slides (top to bottom):

```
+---------------------------+
|  SECTION LABEL (small)    |  10% height
|  SLIDE TITLE              |  30% height — dominant
|  (Large, bold)            |
+---------------------------+
|  PRIMARY VISUAL           |  35% height
|  (Chart or image)         |
+---------------------------+
|  SUPPORTING TEXT          |  20% height
|  (1-2 lines max)          |
+---------------------------+
|  CTA / SOURCE / PAGE #    |  5% height
+---------------------------+
```

### Full-Width Elements

On vertical slides, all elements should span the full width. No sidebars, no narrow columns.

```css
/* All elements full-width */
.vertical-slide * {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
}
/* Consistent horizontal padding */
.vertical-slide .content-zone {
  padding-left: 48px;
  padding-right: 48px;
}
/* Full-bleed images */
.vertical-slide .hero-image {
  width: 100%;
  padding: 0;
  object-fit: cover;
}
```

### Minimum Font Sizes for Mobile

These minimums assume viewing at arm's length on a phone screen (270-300mm from eyes, ~6-inch phone).

| Text type | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| Title | 52px | 72px | Large, bold, dominant |
| Subtitle | 32px | 42px | — |
| Body text | 28px | 34px | Very limited body text |
| Label / caption | 20px | 24px | — |
| Footer | 18px | 20px | — |

---

## Image and Chart Adaptation for Vertical Format

### Full-Width Hero Images

Hero images work best as full-width, full-bleed backgrounds with overlaid text. Use a semi-transparent overlay to ensure text contrast.

```css
.hero-slide {
  position: relative;
  width: 1080px;
  height: 1920px;
  overflow: hidden;
}
.hero-image {
  width: 100%; height: 100%;
  object-fit: cover;
  object-position: center;
}
.hero-overlay {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  height: 60%;
  background: linear-gradient(to top, rgba(0,0,0,0.85) 0%, transparent 100%);
}
.hero-text {
  position: absolute;
  bottom: 80px;
  left: 48px; right: 48px;
  color: white;
  font-size: 64px;
  font-weight: 900;
}
```

### Simplified Charts for Vertical Format

Charts in vertical slides must be stripped to essentials. Rules:
- Maximum 5 data points (fewer is better)
- Vertical bar charts → use horizontal bars only (they fit full-width naturally)
- Remove all gridlines
- Direct labels on each bar (no legend)
- Oversized values (48px+ font on data labels)

**python-pptx 9:16 horizontal bar chart:**
```python
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.chart.data import ChartData
from pptx.enum.chart import XL_CHART_TYPE

prs = Presentation()
# Set 9:16 slide dimensions
prs.slide_width  = Emu(6858000)   # 720pt = 6858000 EMU
prs.slide_height = Emu(12192000)  # 1280pt = 12192000 EMU

slide_layout = prs.slide_layouts[6]  # blank layout
slide = prs.slides.add_slide(slide_layout)

# Horizontal bar chart — full width, upper portion
chart_data = ChartData()
chart_data.categories = ['Product A', 'Product B', 'Product C', 'Product D']
chart_data.add_series('Revenue', (42, 38, 28, 19))

chart = slide.shapes.add_chart(
    XL_CHART_TYPE.BAR_CLUSTERED,      # BAR = horizontal
    left   = Inches(0.4),
    top    = Inches(3.5),
    width  = Inches(6.7),             # nearly full width of 7.5" slide
    height = Inches(4.5),
    chart_data = chart_data
).chart

# Remove gridlines
chart.value_axis.major_gridlines.format.line.fill.background()
# Large data labels
chart.plots[0].has_data_labels = True
chart.plots[0].data_labels.font.size = Pt(20)

prs.save('vertical_slide.pptx')
```

### Stacked Layout for Data Comparison

For before/after or A/B comparisons in vertical format, stack them vertically:

```
+---------------------------+
|  COMPARISON TITLE         |
+---------------------------+
|  OPTION A                 |
|  [Value / Visual]         |
+---------------------------+
|  OPTION B                 |
|  [Value / Visual]         |
+---------------------------+
|  KEY DIFFERENCE           |
+---------------------------+
```

Never place two charts side-by-side in a 9:16 slide — the horizontal space is insufficient.

---

## python-pptx: Creating 9:16 Presentations

### Basic Setup

```python
from pptx import Presentation
from pptx.util import Emu, Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN

def create_vertical_presentation():
    prs = Presentation()

    # 9:16 aspect ratio: 1080 x 1920 points (at 96 DPI = 11.25" x 20")
    # python-pptx uses EMUs: 1 inch = 914400 EMU
    # Use 720pt x 1280pt (7.5" x 13.33")
    prs.slide_width  = Inches(7.5)   # 6858000 EMU
    prs.slide_height = Inches(13.33) # 12192720 EMU

    return prs

def add_title_slide(prs, title_text, subtitle_text=None, bg_color='#1565C0'):
    layout = prs.slide_layouts[6]  # blank
    slide = prs.slides.add_slide(layout)

    # Background
    bg = slide.background.fill
    bg.solid()
    r, g, b = [int(bg_color.lstrip('#')[i:i+2], 16) for i in (0, 2, 4)]
    bg.fore_color.rgb = RGBColor(r, g, b)

    W = prs.slide_width
    H = prs.slide_height

    # Title: top 45% of slide
    title_box = slide.shapes.add_textbox(
        Inches(0.5), Inches(2.5),
        W - Inches(1.0), Inches(5.0)
    )
    tf = title_box.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.LEFT
    run = p.add_run()
    run.text = title_text
    run.font.size = Pt(54)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    if subtitle_text:
        subtitle_box = slide.shapes.add_textbox(
            Inches(0.5), Inches(8.5),
            W - Inches(1.0), Inches(1.5)
        )
        st = subtitle_box.text_frame
        sp = st.paragraphs[0]
        srun = sp.add_run()
        srun.text = subtitle_text
        srun.font.size = Pt(24)
        srun.font.color.rgb = RGBColor(0xCC, 0xDD, 0xFF)

    return slide
```

### Full Vertical Presentation Template

```python
def build_vertical_deck(slides_data, output_path, palette=None):
    """
    slides_data: list of dicts with keys: type, title, body, image_path
    Types: 'title', 'stat', 'text', 'chart', 'image'
    """
    prs = create_vertical_presentation()

    for slide_spec in slides_data:
        stype = slide_spec.get('type', 'text')
        if stype == 'title':
            add_title_slide(prs, slide_spec['title'], slide_spec.get('subtitle'))
        elif stype == 'stat':
            add_stat_slide(prs, slide_spec['title'], slide_spec['stat'],
                          slide_spec.get('label', ''))
        # ... add more slide types as needed

    prs.save(output_path)
    return output_path
```

---

## HTML Template for 9:16 Vertical Slides

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      width: 1080px;
      height: 1920px;
      overflow: hidden;
      font-family: 'Inter', sans-serif;
    }
    .slide {
      width: 1080px;
      height: 1920px;
      display: flex;
      flex-direction: column;
      background: #0D1B2A;
      color: white;
    }
    .section-label {
      padding: 80px 80px 20px;
      font-size: 22px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.2em;
      opacity: 0.5;
    }
    .slide-title {
      padding: 0 80px 40px;
      font-size: 80px;
      font-weight: 900;
      line-height: 1.05;
      flex: 0 0 auto;
    }
    .visual-zone {
      flex: 0 0 640px;       /* 640px of the 1920px height */
      overflow: hidden;
      background: #1565C0;
    }
    .visual-zone img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .body-zone {
      flex: 1;
      padding: 60px 80px;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }
    .body-text {
      font-size: 34px;
      line-height: 1.5;
      opacity: 0.9;
    }
    .cta-zone {
      padding: 40px 80px 80px;
      font-size: 20px;
      opacity: 0.5;
    }
  </style>
</head>
<body>
  <div class="slide">
    <div class="section-label">Section 3 of 5</div>
    <h1 class="slide-title">Results Exceeded Expectations by 2.4×</h1>
    <div class="visual-zone">
      <!-- Chart or image here -->
    </div>
    <div class="body-zone">
      <p class="body-text">Average user completion rate reached 94%, up from 39% baseline.</p>
    </div>
    <div class="cta-zone">See methodology on slide 12</div>
  </div>
</body>
</html>
```

---

## Quick Decision Guide

```
Is audience mobile-first?
├── Yes → use 9:16
└── No  → use 16:9 unless specific reason

Is content a summary, brief, or teaser?
├── Yes → 9:16 works well (5-10 slides max)
└── No  → evaluate content complexity

Does content require:
├── Side-by-side comparison?   → 16:9
├── Complex tables?            → 16:9
├── Multi-column layout?       → 16:9
├── Only headlines + visuals?  → 9:16
└── Single metric per slide?   → 9:16 (ideal)
```

---

## Export and Delivery

### Export from PowerPoint / Keynote

**PowerPoint:** File > Page Setup > Custom: 7.5" wide × 13.33" tall (or 20.32cm × 33.87cm)

**Keynote:** Document > Slide Size > Custom: 1080 × 1920 px

**Google Slides:** File > Page Setup > Custom > 1080px × 1920px

### Export as Video (for social sharing)

```python
# LibreOffice headless export to images
import subprocess, glob, os

subprocess.run([
    'libreoffice', '--headless', '--convert-to', 'png',
    '--outdir', 'slides_out/', 'vertical_deck.pptx'
])

# Combine to MP4 (ffmpeg required)
subprocess.run([
    'ffmpeg', '-r', '0.5',   # 0.5 fps = 2 seconds per slide
    '-pattern_type', 'glob',
    '-i', 'slides_out/*.png',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    'vertical_summary.mp4'
])
```
