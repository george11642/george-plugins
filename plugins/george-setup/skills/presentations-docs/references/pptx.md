# PPTX / PowerPoint Reference

## When to Use

This reference covers three workflows:
1. **Creating new presentations** from scratch (html2pptx)
2. **Editing existing presentations** (OOXML XML access)
3. **Creating PPTX posters** (HTML-based poster export)

For standard poster requests without format specified, use `latex-posters.md` instead.

**Trigger phrases**: "PPTX", "PowerPoint", "PPT", "edit presentation", "create slides in PowerPoint", "HTML poster".

## Overview

Creates research posters using HTML/CSS, exportable to PDF or PowerPoint. Benefits:
- Modern, responsive layouts
- Easy integration of AI-generated visuals
- Quick iteration and browser preview
- Export to PDF via browser print
- Conversion to PPTX if needed

## AI-Powered Visual Generation

Same requirements as LaTeX posters. Generate ALL visuals before creating HTML.

**Target**: 60-70% visuals, 30-40% text.

### Poster Graphic Requirements

Every prompt must include:
```
POSTER FORMAT REQUIREMENTS (STRICTLY ENFORCE):
- ABSOLUTE MAXIMUM 3-4 elements per graphic (3 is ideal)
- ABSOLUTE MAXIMUM 10 words total
- ALL text GIANT BOLD (80pt+ labels, 120pt+ key numbers)
- High contrast ONLY
- MANDATORY 50% white space minimum
- ONE SINGLE MESSAGE per graphic
```

### Generation Examples

```bash
mkdir -p figures

# Hero image
python scripts/generate_schematic.py "POSTER FORMAT for A0. Hero banner: '[TOPIC]' in HUGE text (120pt+). Dark blue gradient background. ONE iconic visual. Readable from 15 feet." -o figures/hero.png

# Methods - 4 steps max
python scripts/generate_schematic.py "POSTER FORMAT for A0. SIMPLE flowchart ONLY 4 boxes: STEP1 -> STEP2 -> STEP3 -> STEP4. GIANT labels (100pt+). Thick arrows. 50% white space. NO sub-steps." -o figures/workflow.png

# Results - 3 bars max
python scripts/generate_schematic.py "POSTER FORMAT for A0. SIMPLE bar chart ONLY 3 bars: BASELINE (70%), EXISTING (85%), OURS (95%). GIANT percentages ON bars (120pt+). NO axis, NO legend. 50% white space." -o figures/results.png

# Conclusions - 3 key findings
python scripts/generate_schematic.py "POSTER FORMAT for A0. EXACTLY 3 cards: '95%' (150pt) 'ACCURACY' (60pt), '2X' (150pt) 'FASTER' (60pt), checkmark 'READY' (60pt). 50% white space." -o figures/conclusions.png
```

## Content Limits

- **Max sections**: 5-6 (Title, Intro, Methods, Results, Conclusions, Footer)
- **Per section**: 50-100 words max
- **Total poster**: 300-800 words
- **Figures per graphic**: 3-4 elements max

## HTML Template Structure

Standard poster dimensions: 36x48 inches (2592x3456 pt).

```
+---------------------------------------------+
|  HEADER: Title, Authors, Hero Image          |
+---------------+---------------+---------------+
| Introduction  |   Results     |  Discussion   |
|               |               |               |
|   Methods     |   (charts)    | Conclusions   |
|               |               |               |
|  (diagram)    |   (data)      |   (summary)   |
+---------------+---------------+---------------+
|  FOOTER: References & Contact Info           |
+---------------------------------------------+
```

### CSS Variables

```css
body { width: 2592pt; height: 3456pt; }
.header { background: linear-gradient(135deg, #1a365d 0%, #2b6cb0 50%, #3182ce 100%); }
.poster-title { font-size: 108pt; }
.authors { font-size: 48pt; }
.affiliations { font-size: 38pt; }
.block-title { font-size: 52pt; }
.block-content { font-size: 34pt; }
.key-finding { font-size: 36pt; }
```

### Section HTML

```html
<div class="block">
  <h2 class="block-title">Methods</h2>
  <div class="block-content">
    <img src="figures/workflow.png" class="block-image">
    <ul>
      <li>Brief methodology point</li>
    </ul>
  </div>
</div>
```

## Workflow

### Stage 1: Planning
1. Confirm PPTX explicitly requested
2. Size: 36x48" (most common) or A0
3. Outline: 1-3 core messages, 3-5 visuals, 300-800 words

### Stage 2: Generate Visuals
Generate SIMPLE figures with poster format requirements (see above).

### Stage 3: Create HTML Poster
1. Copy template: `cp skills/pptx-posters/assets/poster_html_template.html poster.html`
2. Update content: title, authors, images, text, references
3. Preview: `xdg-open poster.html`

### Stage 4: Export to PDF

**Browser print**:
1. Open in Chrome/Firefox
2. Print > Save as PDF
3. Set paper size to poster dimensions
4. Remove margins, enable background graphics

**Chrome headless**:
```bash
google-chrome --headless --print-to-pdf=poster.pdf --print-to-pdf-no-header --no-margins poster.html
```

### Stage 5: Convert to PPTX (If Required)

**Option 1: LibreOffice**
```bash
libreoffice --headless --convert-to pptx poster.pdf
```

**Option 2: python-pptx**
```python
from pptx import Presentation
from pptx.util import Inches

prs = Presentation()
prs.slide_width = Inches(48)
prs.slide_height = Inches(36)
slide = prs.slides.add_slide(prs.slide_layouts[6])  # Blank
slide.shapes.add_picture("figures/hero.png", Inches(0), Inches(0), width=Inches(48))
prs.save("poster.pptx")
```

## Quality Checklist

### Pre-Generation
- [ ] Each graphic: 3-4 items or less?
- [ ] Simple workflow (3-4 steps, NOT 7+)?
- [ ] All text in 10 words or less?
- [ ] ONE message per graphic?

### Post-Generation (view at 25% zoom)
- [ ] All text readable
- [ ] 3-4 elements or fewer per graphic
- [ ] 50%+ white space
- [ ] Understandable in 2 seconds

### After Export
- [ ] No content cut off at any edge
- [ ] All images display correctly
- [ ] Colors render as expected
- [ ] Text readable at 25% scale
- [ ] Graphics look SIMPLE

## Common Pitfalls

**Graphics**: Too many elements (>5), text too small (specify "GIANT 100pt+"), no white space (add "50% white space"), complex flowcharts (limit to 4 steps).

**HTML/Export**: Content exceeding dimensions (check browser overflow), missing backgrounds in PDF (enable in print settings), wrong paper size, low-resolution images (<300 DPI).

**Content**: Too much text (>1000 words), too many sections (>6), no visual hierarchy.

---

## Creating New PowerPoint Presentations (html2pptx)

Use the html2pptx workflow to create visually rich PowerPoint presentations from HTML slides. This produces high-fidelity PPTX files with accurate positioning.

### Design Principles

Before creating any presentation:
1. Analyze the subject matter -- choose colors/fonts that match the content and audience
2. Use web-safe fonts ONLY: Arial, Helvetica, Times New Roman, Georgia, Courier New, Verdana, Tahoma, Trebuchet MS, Impact
3. State your design approach before writing code
4. Build a 3-5 color palette (dominant + supporting + accent) with strong contrast

### html2pptx Workflow

1. **Create HTML slides** with proper body dimensions:
   - 16:9 (default): `width: 720pt; height: 405pt`
   - 4:3: `width: 720pt; height: 540pt`
   - Use `display: flex` on body to prevent margin collapse
   - ALL text must be inside `<p>`, `<h1>`-`<h6>`, `<ul>`, or `<ol>` -- text in bare `<div>` or `<span>` is silently dropped
   - NEVER use CSS gradients -- rasterize to PNG with Sharp first, then reference as `<img>`
   - Backgrounds/borders/shadows work on `<div>` only, not text elements

2. **Convert HTML to PPTX** using the html2pptx.js library:
   ```javascript
   const pptxgen = require('pptxgenjs');
   const html2pptx = require('./html2pptx');
   const pptx = new pptxgen();
   pptx.layout = 'LAYOUT_16x9';
   const { slide, placeholders } = await html2pptx('slide1.html', pptx);
   // Add charts/tables to placeholder areas using PptxGenJS API
   await pptx.writeFile({ fileName: 'output.pptx' });
   ```

3. **Add dynamic content** (charts, tables) to placeholder areas with PptxGenJS:
   - Use hex colors WITHOUT `#` prefix -- `"FF0000"` not `"#FF0000"` (causes corruption)
   - Charts: `slide.addChart(pptx.charts.BAR, data, { ...placeholders[0] })`
   - Tables: `slide.addTable(rows, { x, y, w, h, border, fill })`

4. **Visual validation**: Generate thumbnail grid and inspect:
   ```bash
   python scripts/thumbnail.py output.pptx workspace/thumbnails --cols 4
   ```
   Check for: text cutoff, overlap, positioning issues, contrast problems.

### Layout Tips

- **Two-column (preferred)**: Header spanning full width, flexbox columns below (40/60 split)
- **Full-slide**: Let chart/table fill the slide for maximum impact
- **Never vertically stack** charts below text in a single column

### Rasterizing Icons and Gradients

CSS gradients and SVG icons don't convert to PowerPoint. Pre-render as PNG:

```javascript
const sharp = require('sharp');
// Gradient background
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="563">
  <defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
    <stop offset="0%" style="stop-color:#COLOR1"/><stop offset="100%" style="stop-color:#COLOR2"/>
  </linearGradient></defs>
  <rect width="100%" height="100%" fill="url(#g)"/></svg>`;
await sharp(Buffer.from(svg)).png().toFile('gradient-bg.png');
```

For icons, use react-icons with ReactDOMServer.renderToStaticMarkup() then Sharp to rasterize.

---

## Editing Existing PowerPoint Presentations (OOXML)

A .pptx file is a ZIP archive of XML files. Edit by unpacking, modifying XML, validating, and repacking.

### Key File Structure

| Path | Content |
|------|---------|
| `ppt/presentation.xml` | Main metadata, slide references |
| `ppt/slides/slide{N}.xml` | Individual slide content |
| `ppt/notesSlides/notesSlide{N}.xml` | Speaker notes |
| `ppt/slideLayouts/` | Layout templates |
| `ppt/slideMasters/` | Master templates |
| `ppt/theme/theme1.xml` | Colors (`<a:clrScheme>`) and fonts (`<a:fontScheme>`) |
| `ppt/media/` | Images and media |
| `ppt/slides/_rels/slideN.xml.rels` | Per-slide relationships |

### OOXML Editing Workflow

```bash
# 1. Unpack
python ooxml/scripts/unpack.py presentation.pptx unpacked/

# 2. Read text content
python -m markitdown presentation.pptx

# 3. Edit XML files (slides, notes, etc.)

# 4. Validate after EACH edit
python ooxml/scripts/validate.py unpacked/ --original presentation.pptx

# 5. Repack
python ooxml/scripts/pack.py unpacked/ output.pptx
```

### XML Patterns Quick Reference

**Text box with formatting**:
```xml
<p:txBody>
  <a:bodyPr/><a:lstStyle/>
  <a:p>
    <a:r>
      <a:rPr lang="en-US" sz="2400" b="1" dirty="0">
        <a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>
      </a:rPr>
      <a:t>Bold red 24pt text</a:t>
    </a:r>
  </a:p>
</p:txBody>
```

**Element order in `<p:txBody>`**: `<a:bodyPr>` then `<a:lstStyle>` then `<a:p>` (schema-mandatory).

**Formatting attributes**: `b="1"` (bold), `i="1"` (italic), `u="sng"` (underline), `sz="2400"` (24pt in hundredths-of-point).

**Bullet list**:
```xml
<a:p><a:pPr lvl="0"><a:buChar char="&#x2022;"/></a:pPr>
  <a:r><a:t>Bullet point</a:t></a:r></a:p>
```

**Image** (requires relationship in `_rels/slideN.xml.rels`):
```xml
<p:pic>
  <p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
  <p:spPr><a:xfrm><a:off x="1000000" y="1000000"/><a:ext cx="3000000" cy="2000000"/></a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>
</p:pic>
```

### File Updates When Adding Content

Update ALL of these when adding slides/images:
1. `[Content_Types].xml` -- declare new parts
2. `ppt/_rels/presentation.xml.rels` -- add relationship
3. `ppt/presentation.xml` -- add `<p:sldId>` to `<p:sldIdLst>`
4. `ppt/slides/_rels/slideN.xml.rels` -- per-slide resources
5. `docProps/app.xml` -- update slide count (if present)

### Common OOXML Errors

- Missing `dirty="0"` on `<a:rPr>` and `<a:endParaRPr>`
- Wrong element order in `<p:txBody>`
- Unicode not escaped in ASCII content (`"` -> `&#8220;`)
- Adding `xml:space='preserve'` missing on `<a:t>` with leading/trailing spaces
- Orphaned media references after slide deletion

---

## Template-Based Presentation Creation

Use when you need to match an existing template's design.

### Workflow

1. **Analyze template**: Extract text with `python -m markitdown template.pptx`, create thumbnail grid with `python scripts/thumbnail.py template.pptx`

2. **Create inventory**: Document every slide's layout type, content areas, and design patterns. Save to `template-inventory.md` with 0-based slide indices.

3. **Map content to templates**: Choose layouts that match your content structure. Save to `outline.md` with template mapping:
   ```python
   template_mapping = [0, 34, 34, 50, 54]  # 0-based slide indices
   ```

4. **Rearrange slides**: `python scripts/rearrange.py template.pptx working.pptx 0,34,34,50,54`

5. **Extract text inventory**: `python scripts/inventory.py working.pptx text-inventory.json` -- returns JSON with all shapes, positions, placeholder types, and formatting.

6. **Generate replacement text**: Create `replacement-text.json` with new paragraphs per shape. Shapes not listed are auto-cleared. Include formatting properties (bold, bullet, alignment, color).

7. **Apply replacements**: `python scripts/replace.py working.pptx replacement-text.json output.pptx`

### Critical Rules for Template Work

- Slide indices are 0-based (first slide = 0)
- Match layout columns to actual content count (2 items -> 2-column, not 3-column)
- Never use quote layouts for non-quotes
- Bullets auto-inserted when `"bullet": true` -- never include bullet symbols in text
- The replace script validates shape existence and reports overflow

---

## Converting Slides to Images

```bash
# PPTX -> PDF -> images
soffice --headless --convert-to pdf presentation.pptx
pdftoppm -jpeg -r 150 presentation.pdf slide    # creates slide-1.jpg, slide-2.jpg, etc.
pdftoppm -jpeg -r 150 -f 2 -l 5 presentation.pdf slide  # specific page range
```

## Dependencies

- **markitdown**: `pip install "markitdown[pptx]"` (text extraction)
- **pptxgenjs**: `npm install -g pptxgenjs` (PPTX creation)
- **playwright**: `npm install -g playwright` (HTML rendering)
- **sharp**: `npm install -g sharp` (SVG/image rasterization)
- **LibreOffice**: `sudo apt-get install libreoffice` (PDF conversion)
- **Poppler**: `sudo apt-get install poppler-utils` (pdftoppm)
- **defusedxml**: `pip install defusedxml` (secure XML parsing)
