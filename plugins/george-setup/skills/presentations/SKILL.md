---
name: presentations
description: "Use when creating presentations, research posters (PPTX or LaTeX), converting papers to web format, or building slide decks. Covers conference talks, seminar slides, thesis defense presentations, academic posters, paper-to-web/video/poster pipelines, PowerPoint presentation/poster generation, pptx template-based workflows, thumbnail grid analysis, slide inventory extraction, batch content replacement, slide rearrangement, OOXML editing, theme selection, color palette, color palette design, accessibility, WCAG, color-blind design, bento grid, bento layout, vertical slides, 9:16, portrait slides, mobile presentations, layout patterns, geometric layout, asymmetric columns, typography-first layout, storyboarding, narrative arc, story structure, data simplification, Sankey diagram, donut chart, dot plot, funnel chart, horizontal bar chart, and pptx scripts."
---

# Presentations Master Skill

## Task Router

| User Request | Reference | Notes |
|---|---|---|
| Slide deck, conference talk, seminar, thesis defense, grant pitch | `references/slides.md` | Default: PDF via Nano Banana Pro |
| Research/conference/A0 poster, LaTeX poster | `references/latex-posters.md` | Default for poster requests |
| PPTX poster, PowerPoint poster, HTML poster | `references/pptx.md` | Only when PPTX explicitly requested |
| Create/edit PowerPoint presentations (from scratch) | `references/pptx.md` | html2pptx or OOXML editing workflows |
| PowerPoint template, pptx template, use existing template | `references/pptx-templates.md` | thumbnail → rearrange → inventory → replace |
| Thumbnail grid, visual slide overview, pptx thumbnails | `references/pptx-templates.md` | Use `scripts/thumbnail.py` |
| Inventory slides, extract text shapes, slide inventory | `references/pptx-templates.md` | Use `scripts/inventory.py` |
| Batch replace content, replace slide text, content mapping | `references/pptx-templates.md` | Use `scripts/replace.py` |
| Rearrange slides, reorder slides, duplicate slides, delete slides | `references/pptx-templates.md` | Use `scripts/rearrange.py` |
| OOXML editing, unpack pptx, edit XML, validate pptx | `references/pptx-templates.md` | Use `scripts/ooxml/` tools |
| Theme selection, color palette, apply theme, styled presentation | `references/theme-factory.md` | 10 pre-built themes with hex codes |
| Color palette design, palette selection methodology, color psychology | `references/color-palette-design.md` | 18 curated palettes with hex codes, 5-step methodology |
| Convert paper to website/video/poster | `references/paper-to-web.md` | Paper2All pipeline |
| Layout patterns, bento grid, bento layout, geometric shapes, asymmetric columns, Z-pattern, F-pattern | `references/layout-patterns.md` | Diagonal dividers, border treatments, typography-first, bento HTML templates |
| Accessibility, WCAG, color-blind, inclusive design, contrast ratio, alt text | `references/accessibility-inclusive-design.md` | WCAG AA/AAA standards, Okabe-Ito palette, testing checklist |
| Vertical slides, 9:16, mobile presentations, portrait slides, social sharing | `references/mobile-presentations.md` | 1080×1920px specs, python-pptx 9:16 setup, HTML template |
| Data simplification, chart selection 2026, Sankey, donut chart, dot plot, funnel | `references/data-visualization-2026.md` | Anti-patterns, styling rules, code for each chart type |
| Storyboarding, narrative arc, story structure, presentation flow, talk planning | `references/narrative-storyboarding.md` | Arc template with timing, slide-level beats, review checklist |

**Defaults**: "poster" without format -> LaTeX. "Presentation" without format -> PDF slides. "Use this template" -> pptx-templates workflow.

## Shared Principles

### Visual-First Design

All presentation types: plan visuals first, generate with scientific-schematics or Nano Banana Pro, review at reduced scale (25% posters, 50% slides), then assemble.

**Target**: 60-70% visual content, 30-40% text across all formats.

### Poster Graphics Requirements (LaTeX and PPTX)

Every poster graphic prompt must include:
```
POSTER FORMAT REQUIREMENTS (STRICTLY ENFORCE):
- ABSOLUTE MAXIMUM 3-4 elements per graphic (3 is ideal)
- ABSOLUTE MAXIMUM 10 words total in the entire graphic
- ALL text GIANT BOLD (80pt+ for labels, 120pt+ for key numbers)
- High contrast ONLY (dark on white OR white on dark)
- MANDATORY 50% white space minimum
- ONE SINGLE MESSAGE per graphic
```

**Reject if ANY true**: 5+ items (split into multiple graphics), 5+ workflow stages (show 3-4 high-level steps), 4+ methods compared (show top 3 or ours vs best).

### Slide Design Philosophy

- **Compelling visuals**: Figures, diagrams dominate every slide
- **Minimal text**: 3-4 bullets, 4-6 words each, 24-28pt body
- **Modern design**: Contemporary palettes, not default themes
- **Story-driven**: Clear narrative arc with visual anchors
- **Research-backed**: Proper citations (8-15 papers recommended)

### Content Limits

| Format | Max Words | Max Sections/Slides | Font Min |
|--------|-----------|-------------------|----------|
| Poster (A0) | 300-800 | 5-6 sections | 24pt body |
| Slides (15 min) | ~50/slide | 15-18 slides | 24pt body |
| Slides (45 min) | ~50/slide | 40-50 slides | 24pt body |

### Slide Quality Thresholds

Fail any slide that violates these -- fix before proceeding:
- **Text overflow**: No text clipped or running off-slide
- **Readability**: All body text 24pt+, titles 32pt+, readable at 50% zoom
- **Contrast**: 4.5:1 minimum (7:1 preferred) for text on background
- **Density**: Max 6 lines of text per slide; max 40 words per slide
- **Consistency**: Same font family, color palette, and layout grid across all slides
- **Whitespace**: 20%+ whitespace per slide; no edge-to-edge text blocks

### Visual Validation Workflow

1. Generate PDF or images
2. Convert to images if needed (`pdf_to_images.py` or `pdftoppm`)
3. Systematic inspection: overflow, overlap, font size, contrast
4. Document issues with slide/section numbers
5. Fix and re-validate (max 2 iterations)

### Preventing Content Overflow (Posters)

1. Limit to 5-6 sections maximum
2. Safe margins: 25mm+ for tikzposter, generous colspacing for baposter
3. Never use `width=\linewidth` for figures -- use `0.85\linewidth`
4. Check: `grep "Overfull" poster.log`
5. Word count: 50-100 words per section, 300-800 total

## Implementation Workflows

### Slides: PDF Workflow (Default)

```bash
# 1. Generate each slide as image with consistent formatting
python scripts/generate_slide_image.py "Title slide: '...' FORMATTING GOAL: [colors], minimal professional design." -o slides/01_title.png

# 2. Subsequent slides: attach previous for consistency + citations
python scripts/generate_slide_image.py "Content slide... CITATIONS: (Author et al., Year). FORMATTING GOAL: Match attached slide." -o slides/02_intro.png --attach slides/01_title.png

# 3. Results slides: attach actual data figures
python scripts/generate_slide_image.py "Results slide..." -o slides/04_results.png --attach slides/03.png --attach figures/chart.png

# 4. Combine to PDF
python scripts/slides_to_pdf.py slides/*.png -o presentation.pdf
```

### Slides: PowerPoint Workflow

Use the html2pptx workflow from `references/pptx.md` -- create HTML slides, convert via html2pptx.js, add charts/tables with PptxGenJS. For template-based presentations, use the OOXML editing workflow (unpack, edit XML, validate, repack).

### Slides: LaTeX Beamer

Generate Beamer templates inline -- standard packages: `beamer` with `\usetheme{}`. Choose theme to match formality: `metropolis` (modern), `Madrid` (traditional), `default` (minimal). Include `\usepackage{graphicx,tikz,booktabs}` for figures and tables.

### LaTeX Poster Workflow

1. Choose package: tikzposter (modern), baposter (structured), beamerposter (institutional)
2. Generate AI visuals with poster format requirements
3. Post-generation review at 25% zoom
4. Assemble in LaTeX template
5. Compile: `pdflatex poster.tex`
6. Overflow check + visual inspection

### PPTX Poster Workflow (Only When Explicitly Requested)

1. Generate AI visuals with poster format requirements
2. Create HTML poster (36x48" or A0), preview in browser
3. Export to PDF via Chrome headless: `google-chrome --headless --print-to-pdf=poster.pdf --no-margins poster.html`
4. Convert to PPTX if needed (LibreOffice or python-pptx)

### Paper-to-Web Pipeline

```bash
python pipeline_all.py --input-dir "path/to/paper" --output-dir "path/to/output" --model-choice 1
# Add: --generate-website, --generate-poster, or use pipeline_light.py for video
```

## Speaker Notes and Delivery

Add speaker notes for every slide -- they serve as the presenter's script and improve accessibility.

- **Timing**: Plan 1-2 minutes per slide (15-min talk = 10-12 content slides + title/questions)
- **Notes format**: 2-3 bullet points per slide; key phrase to say, not a script to read
- **Transitions**: End each note with a bridge sentence to the next slide
- **Q&A buffer**: Reserve 15-20% of allotted time for questions
- **Narrative arc**: Opening hook -> problem -> approach -> results -> impact -> call to action
- **Rehearsal tip**: Run through once at 80% of allotted time to leave margin

For PDF slides, keep notes in a separate document. For PPTX, embed via speaker notes pane. For Beamer, use `\note{}` with `\usepackage{pgfpages}` for notes pages.

## Tools and Scripts

### Slide Generation (PDF workflow)

| Tool | Purpose |
|------|---------|
| `generate_slide_image.py` | Full slides or visuals via Nano Banana Pro |
| `slides_to_pdf.py` | Combine slide images into PDF |
| `validate_presentation.py` | Check slide count, file size, dimensions |
| `pdf_to_images.py` | Convert PDF to images for review |
| `generate_schematic.py` | AI poster graphics via scientific-schematics |
| `review_poster.sh` | Automated poster PDF quality checks |
| `pipeline_all.py` / `pipeline_light.py` | Paper2All (web + poster + video) |

### PPTX Scripts (in `scripts/`)

| Tool | Purpose |
|------|---------|
| `scripts/thumbnail.py` | Create visual thumbnail grids from .pptx slides; 5-col default, configurable layout, handles hidden slides |
| `scripts/inventory.py` | Extract all text shapes from .pptx with formatting details (position, font, bullets, spacing, overflow detection) |
| `scripts/replace.py` | Batch-replace slide content from a JSON spec; clears shapes not in spec, validates all references |
| `scripts/rearrange.py` | Reorder/duplicate/delete slides by 0-based index list; creates new presentation from template subset |
| `scripts/html2pptx.js` | Convert HTML slide files to .pptx with accurate positioning via Playwright + PptxGenJS |

### OOXML Scripts (in `scripts/ooxml/`)

| Tool | Purpose |
|------|---------|
| `scripts/ooxml/unpack.py` | Unzip .pptx into editable directory of XML files |
| `scripts/ooxml/validate.py` | Validate unpacked directory against OOXML schemas; compare to original |
| `scripts/ooxml/pack.py` | Repack edited XML directory back into a .pptx file |

## Integration

- **Scientific Schematics**: All diagrams and flowcharts
- **Data Visualization**: Presentation-appropriate figures
- **Scientific Writing**: Paper content to presentation format

## Reference Files

- `references/slides.md` -- Scientific slides guide (structure, design, timing)
- `references/latex-posters.md` -- LaTeX poster packages, templates, checklists
- `references/pptx.md` -- PowerPoint creation (html2pptx, OOXML editing) and HTML poster export
- `references/pptx-templates.md` -- Template-based workflow: thumbnail grid, inventory, rearrange, replace; color palettes; OOXML editing; dependencies
- `references/theme-factory.md` -- 10 pre-built themes with hex codes and font pairings; selection logic; custom theme generation; application checklist
- `references/paper-to-web.md` -- Paper2All pipeline for websites, videos, posters
- `references/layout-patterns.md` -- Geometric layouts, bento grid HTML templates, asymmetric columns, border/frame treatments, typography-first layouts, background treatments, Z/F-pattern flow
- `references/color-palette-design.md` -- 18 curated palettes with hex codes, 5-step selection methodology, color psychology, custom theme generation, python-pptx application
- `references/accessibility-inclusive-design.md` -- WCAG AA/AAA contrast standards, color-blind-safe palettes (Okabe-Ito), dyslexia-friendly fonts, chart accessibility, cognitive accessibility, testing checklist
- `references/mobile-presentations.md` -- 9:16 vertical slide specs (1080×1920px), python-pptx setup, HTML template, chart adaptation, export to video
- `references/data-visualization-2026.md` -- 2026 simplification principle, chart type selection guide, donut/Sankey/funnel/dot-plot/horizontal-bar examples, anti-patterns, styling rules
- `references/narrative-storyboarding.md` -- Storyboard framework, narrative arc template with timing distribution, slide-level beat types, pre-build review checklist
