# PPTX Template Workflow Reference

This document covers the complete template-based PowerPoint creation workflow: analyzing templates visually, building an inventory, rearranging slides, and replacing content.

## Overview: Template-Based Workflow (4 Steps)

```
1. thumbnail.py  →  Visual grid of all slides (identify layouts)
2. rearrange.py  →  Select and order template slides into working deck
3. inventory.py  →  Extract all text shapes with formatting details
4. replace.py    →  Batch-replace content, clear unused shapes
```

Use this workflow when the user provides an existing `.pptx` template to base their presentation on.

---

## Step 1: Visual Analysis with Thumbnail Grid

### Creating Thumbnail Grids

```bash
# Basic usage — creates thumbnails.jpg
python scripts/thumbnail.py template.pptx

# Custom output prefix
python scripts/thumbnail.py template.pptx workspace/analysis

# 4-column grid (for large decks)
python scripts/thumbnail.py template.pptx workspace/analysis --cols 4

# Outline text shapes in red (useful for placeholder mapping)
python scripts/thumbnail.py template.pptx analysis --outline-placeholders
```

**Grid limits by column count**:
- 3 cols: max 12 slides per grid (3×4)
- 4 cols: max 20 slides per grid (4×5)
- 5 cols: max 30 slides per grid (5×6) — default
- 6 cols: max 42 slides per grid (6×7)

For large decks, multiple files are created automatically: `thumbnails-1.jpg`, `thumbnails-2.jpg`, etc.

**Slides are zero-indexed**: Slide 0 is the first slide. Always use 0-based indices in all scripts.

### Reading the Thumbnail Grid

After running `thumbnail.py`, read the output image(s) carefully. For each slide, note:
- Layout pattern (title-only, title+body, two-column, full-image, section divider, quote)
- Image placeholder locations and counts
- Number of text shapes visible
- Visual hierarchy

### Saving a Template Inventory File

Create `template-inventory.md` after thumbnail analysis:

```markdown
# Template Inventory Analysis
**Total Slides: [count]**
**IMPORTANT: Slides are 0-indexed (first slide = 0, last slide = count-1)**

## Cover / Title Slides
- Slide 0: Cover with large title and subtitle
- Slide 1: Alternate cover (dark background)

## Section Dividers
- Slide 5: Section divider — large number + heading
- Slide 6: Section divider — full bleed color

## Content Layouts
- Slide 10: Title + body text (single column)
- Slide 11: Title + two-column text
- Slide 12: Title + image left + text right
- Slide 13: Title + three-column (icons + text)

## Closing Slides
- Slide 70: Thank you / contact
- Slide 72: Q&A
```

This file is required input for Step 2 — you must know slide indices before rearranging.

---

## Step 2: Rearrange Slides with rearrange.py

```bash
python scripts/rearrange.py template.pptx working.pptx 0,34,34,50,52
```

**How it works**:
- Takes a comma-separated list of 0-based slide indices
- Duplicates slides that appear multiple times
- Deletes slides not listed
- Produces a new file (`working.pptx`) with only the selected slides in order

**Creating a template mapping**:

```python
# WARNING: Verify indices are within range!
# A template with 73 slides has indices 0–72
template_mapping = [
    0,   # Cover slide
    34,  # B1: Title and body  (for slide 2 of deck)
    34,  # B1 again            (duplicate for slide 3)
    11,  # Two-column          (for slide 4)
    50,  # E1: Quote layout    (for slide 5)
    54,  # F2: Closing         (final slide)
]
# Command:
# python scripts/rearrange.py template.pptx working.pptx 0,34,34,11,50,54
```

**Layout selection rules**:
- Title slides: use one of the first 3 slides in the template
- Single-topic content: use single-column body layouts
- Two-column: ONLY when you have exactly 2 distinct items/concepts
- Three-column: ONLY when you have exactly 3 distinct items/concepts
- Quote layouts: ONLY for actual attributed quotes, never for emphasis
- Image+text: ONLY when you have real images to insert
- Never put more content in a layout than it has placeholders for

---

## Step 3: Extract Text Inventory with inventory.py

```bash
python scripts/inventory.py working.pptx text-inventory.json
```

**Options**:
```bash
# Extract only shapes with overflow/overlap issues
python scripts/inventory.py working.pptx issues.json --issues-only
```

### Understanding the Inventory JSON

```json
{
  "slide-0": {
    "shape-0": {
      "placeholder_type": "TITLE",
      "left": 1.5,
      "top": 2.0,
      "width": 7.5,
      "height": 1.2,
      "default_font_size": 36.0,
      "paragraphs": [
        {
          "text": "Existing title text",
          "alignment": "CENTER",
          "bold": true,
          "font_size": 36.0
        }
      ]
    },
    "shape-1": {
      "placeholder_type": "SUBTITLE",
      "left": 2.0,
      "top": 3.5,
      "width": 6.0,
      "height": 1.0,
      "paragraphs": [
        {
          "text": "Existing subtitle text"
        }
      ]
    }
  }
}
```

**Key details**:
- Slides: `"slide-0"`, `"slide-1"`, etc. (0-based)
- Shapes: `"shape-0"`, `"shape-1"`, etc. (sorted top-to-bottom, left-to-right)
- **Placeholder types**: `TITLE`, `CENTER_TITLE`, `SUBTITLE`, `BODY`, `OBJECT`, or `null` for non-placeholders
- `default_font_size`: inherited from layout — use this to set appropriate text length
- Slide number shapes (`SLIDE_NUMBER` type) are automatically excluded
- Properties only appear when non-default (e.g., `bold: true` but not `bold: false`)

**Overflow and overlap detection**:
- `"overflow"."frame"."overflow_bottom"`: text exceeds shape height (in inches)
- `"overflow"."slide"."overflow_right"` / `"overflow_bottom"`: shape exceeds slide boundary
- `"overlap"."overlapping_shapes"`: dict of shape_id → overlap area (sq inches)
- `"warnings"`: e.g., `"manual_bullet_symbol: use proper bullet formatting"`

---

## Step 4: Replace Content with replace.py

```bash
python scripts/replace.py working.pptx replacement-text.json output.pptx
```

### Replacement JSON Format

```json
{
  "slide-0": {
    "shape-0": {
      "paragraphs": [
        {
          "text": "New Presentation Title",
          "alignment": "CENTER",
          "bold": true
        }
      ]
    },
    "shape-1": {
      "paragraphs": [
        {
          "text": "Speaker Name • Organization • Date"
        }
      ]
    }
  },
  "slide-1": {
    "shape-0": {
      "paragraphs": [
        {
          "text": "Section Header",
          "bold": true
        },
        {
          "text": "First bullet point",
          "bullet": true,
          "level": 0
        },
        {
          "text": "Second bullet point",
          "bullet": true,
          "level": 0
        },
        {
          "text": "Sub-point under second",
          "bullet": true,
          "level": 1
        }
      ]
    }
  }
}
```

### Critical Replace Rules

1. **Shapes not in replacement JSON are automatically cleared** — you don't need to list every shape, only those with new content
2. **`bullet: true` requires `level`** — level is always required when bullet is true (even if 0)
3. **Never include bullet symbols in text** — do not use `•`, `-`, or `*`; bullets are added automatically
4. **Preserve key paragraph properties** from the original inventory: `alignment`, `font_name`, `font_size`, `bold`, `color`, `theme_color`
5. **Bullets are left-aligned automatically** — do not set `alignment` on bullet paragraphs
6. **shape IDs must exist** in the inventory — the script validates all shape references before applying changes

### Common Formatting Patterns

| Content Type | Required Properties |
|---|---|
| Title | `"bold": true`, optionally `"alignment": "CENTER"` |
| Section header | `"bold": true` |
| Bullet list item | `"bullet": true, "level": 0` |
| Sub-bullet | `"bullet": true, "level": 1` |
| Centered body | `"alignment": "CENTER"` |
| Colored text | `"color": "FF0000"` (RGB hex) or `"theme_color": "DARK_1"` |
| Quote | typically `"alignment": "CENTER"` or `"italic": true` |

### Validation Errors

The replace.py script shows all validation errors before exiting:

```
ERROR: Invalid shapes in replacement JSON:
  - Shape 'shape-99' not found on 'slide-0'. Available shapes: shape-0, shape-1, shape-4
  - Slide 'slide-999' not found in inventory

ERROR: Replacement text made overflow worse in these shapes:
  - slide-0/shape-2: overflow worsened by 1.25" (was 0.00", now 1.25")
```

Fix errors by checking the inventory for correct shape IDs and reducing text length for overflow issues.

---

## Content Mapping Process

### 1. Write the Outline First

Before selecting template slides, write the full presentation outline:

```markdown
# Presentation Outline

Slide 1: Title — "Machine Learning in Drug Discovery"
  - Subtitle: "Accelerating Target Identification"
  - Presenter: Dr. Jane Smith, Pharma Corp, 2025

Slide 2: The Problem
  - Current drug discovery takes 12+ years
  - Only 10% of candidates reach clinical trials
  - Key bottleneck: target identification

Slide 3: Our Approach
  - [Two-column] Column A: Traditional methods | Column B: ML-augmented pipeline
  ...
```

### 2. Map Outline to Template Slides

For each outline slide, identify the best matching template layout from `template-inventory.md`. Count content items first:
- 1 topic → single-column layout
- 2 topics → two-column layout (not a three-column with one empty)
- 3+ bullets → body layout (not individual text boxes)

### 3. Build rearrange Command

Convert your mapping to a comma-separated index list, then run rearrange.py.

### 4. Populate Replacement JSON

Read the full `text-inventory.json`, then for each slide build the replacement JSON. Use `default_font_size` from inventory to judge appropriate text length — a shape with `default_font_size: 14` can hold more text than one with `default_font_size: 36`.

---

## Reading and Analyzing Existing Presentations

### Text Extraction (Quick Read)

```bash
# Convert to markdown for fast content inspection
python -m markitdown presentation.pptx > content.md
```

### Raw XML Access

For comments, animations, speaker notes, design elements — unpack first:

```bash
python scripts/ooxml/unpack.py presentation.pptx unpacked/
```

**Key XML files**:
- `ppt/presentation.xml` — slide list and metadata
- `ppt/slides/slide{N}.xml` — per-slide content (1-indexed)
- `ppt/notesSlides/notesSlide{N}.xml` — speaker notes
- `ppt/theme/theme1.xml` — colors (`<a:clrScheme>`) and fonts (`<a:fontScheme>`)
- `ppt/slideLayouts/` — layout templates
- `ppt/slideMasters/` — master slide templates
- `ppt/media/` — embedded images

### Typography/Color Extraction from Existing Design

When told to emulate an existing presentation's design:
1. Read `ppt/theme/theme1.xml` for the color scheme and font scheme
2. Sample `ppt/slides/slide1.xml` for actual font usage (`<a:rPr>`) and colors
3. Search patterns: `<a:solidFill>`, `<a:srgbClr>`, `<a:clrScheme>`, `<a:fontScheme>`

---

## Color Palette Reference (18 Palettes)

Use these to spark creativity. Pick one, adapt it, or create your own. Build a palette of 3–5 colors (dominant + supporting + accent).

| # | Name | Colors (hex) | Best For |
|---|---|---|---|
| 1 | Classic Blue | `#1C2833` `#2E4053` `#AAB7B8` `#F4F6F6` | Finance, consulting, trust |
| 2 | Teal & Coral | `#5EA8A7` `#277884` `#FE4447` `#FFFFFF` | Healthcare, wellness, modern |
| 3 | Bold Red | `#C0392B` `#E74C3C` `#F39C12` `#F1C40F` `#2ECC71` | High energy, sales, sports |
| 4 | Warm Blush | `#A49393` `#EED6D3` `#E8B4B8` `#FAF7F2` | Fashion, beauty, lifestyle |
| 5 | Burgundy Luxury | `#5D1D2E` `#951233` `#C15937` `#997929` | Wine, luxury, hospitality |
| 6 | Deep Purple & Emerald | `#B165FB` `#181B24` `#40695B` `#FFFFFF` | Tech, gaming, creative |
| 7 | Cream & Forest Green | `#FFE1C7` `#40695B` `#FCFCFC` | Organic, sustainability |
| 8 | Pink & Purple | `#F8275B` `#FF574A` `#FF737D` `#3D2F68` | Entertainment, pop culture |
| 9 | Lime & Plum | `#C5DE82` `#7C3A5F` `#FD8C6E` `#98ACB5` | Creative agencies, design |
| 10 | Black & Gold | `#BF9A4A` `#000000` `#F4F6F6` | Awards, luxury, gala |
| 11 | Sage & Terracotta | `#87A96B` `#E07A5F` `#F4F1DE` `#2C2C2C` | Food, earthy brands |
| 12 | Charcoal & Red | `#292929` `#E33737` `#CCCBCB` | Bold, startup, tech |
| 13 | Vibrant Orange | `#F96D00` `#F2F2F2` `#222831` | Energy, innovation, youth |
| 14 | Forest Green | `#191A19` `#4E9F3D` `#1E5128` `#FFFFFF` | Environment, outdoor, bio |
| 15 | Retro Rainbow | `#722880` `#D72D51` `#EB5C18` `#F08800` `#DEB600` | Creative, vintage, festival |
| 16 | Vintage Earthy | `#E3B448` `#CBD18F` `#3A6B35` `#F4F1DE` | Artisan, farm, heritage |
| 17 | Coastal Rose | `#AD7670` `#B49886` `#F3ECDC` `#BFD5BE` | Spa, wellness, boutique |
| 18 | Orange & Turquoise | `#FC993E` `#667C6F` `#FCFCFC` | Tropical, surf, casual |

---

## Typography Treatment Options

**Size contrast** (pick one approach per deck):
- Extreme contrast: 72pt headlines vs 11pt captions
- Modern: 48pt title, 24pt body, 14pt caption
- Dense data: 32pt title, 16pt body (Arial Narrow for more text per line)

**Formatting conventions**:
- All-caps headers with wide letter spacing → corporate, editorial
- Monospace (Courier New) for data / stats / code → technical credibility
- Condensed (Arial Narrow) for dense information → fits more without going small
- Title bold + subtitle regular → clear hierarchy without font mixing

**Web-safe fonts only** (guaranteed to render in PPTX):
Arial, Helvetica, Times New Roman, Georgia, Courier New, Verdana, Tahoma, Trebuchet MS, Impact, Arial Narrow

---

## Visual Detail Options for Slide Design

### Geometric Patterns
- Diagonal section dividers instead of horizontal
- Asymmetric column widths (30/70, 40/60, 25/75)
- Rotated text headers at 90° or 270°
- Triangular accent shapes in corners
- Overlapping shapes for depth

### Border and Frame Treatments
- Thick single-color border (10–20pt) on one side only
- Double-line borders with contrasting colors
- L-shaped borders (top+left or bottom+right)
- Underline accents beneath headers (3–5pt thick)

### Chart and Data Styling
- Monochrome charts with single accent color for key data
- Horizontal bar charts instead of vertical
- Dot plots instead of bar charts
- Minimal or no gridlines
- Data labels directly on elements (no legends)
- Oversized numbers for key metrics

### Layout Innovations
- Full-bleed images with text overlays
- Sidebar column (20–30% width) for navigation/context
- Magazine-style multi-column layouts
- Floating text boxes over colored shapes

### Background Treatments
- Solid color blocks occupying 40–60% of slide
- Split backgrounds (two colors, diagonal or vertical)
- Edge-to-edge color bands
- Gradient fills (vertical or diagonal only)

---

## Converting Slides to Images (for Visual QA)

```bash
# Step 1: Convert PPTX to PDF
soffice --headless --convert-to pdf presentation.pptx

# Step 2: Convert PDF pages to JPEG
pdftoppm -jpeg -r 150 presentation.pdf slide
# Creates: slide-1.jpg, slide-2.jpg, etc.

# Specific page range only
pdftoppm -jpeg -r 150 -f 2 -l 5 presentation.pdf slide

# PNG instead of JPEG
pdftoppm -png -r 150 presentation.pdf slide
```

Use thumbnail.py for a quick grid view; use pdftoppm for detailed per-slide inspection.

---

## OOXML Editing Workflow (for Direct XML Edits)

When editing complex formatting, animations, or elements not accessible via python-pptx:

```bash
# 1. Unpack
python scripts/ooxml/unpack.py presentation.pptx unpacked/

# 2. Edit XML files (use standard text editor or Edit tool)
# Primary files: ppt/slides/slide{N}.xml (1-indexed)

# 3. Validate after every change — fix before proceeding
python scripts/ooxml/validate.py unpacked/ --original presentation.pptx

# 4. Repack
python scripts/ooxml/pack.py unpacked/ output.pptx
```

**Validate immediately after each XML edit**. Do not accumulate multiple edits before validating.

---

## Dependencies

```bash
pip install "markitdown[pptx]"    # Text extraction
pip install python-pptx           # Core PPTX manipulation
pip install Pillow                # Image processing (thumbnail.py)
pip install defusedxml            # Secure XML parsing (ooxml scripts)
npm install -g pptxgenjs          # Chart/table creation (html2pptx.js)
npm install -g playwright         # HTML rendering (html2pptx.js)
npm install -g sharp              # SVG rasterization (html2pptx.js)
sudo apt-get install libreoffice  # PDF conversion (thumbnail.py)
sudo apt-get install poppler-utils # pdftoppm
```
