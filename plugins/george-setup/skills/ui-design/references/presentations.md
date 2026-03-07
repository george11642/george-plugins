# Presentations: PPTX, Slides, LaTeX Posters

## PPTX Creation (html2pptx Workflow)

### From Scratch
1. Design slide HTML files (720pt x 405pt for 16:9)
2. Convert HTML to PPTX using `html2pptx.js`
3. Add charts/tables via PptxGenJS API
4. Validate with thumbnail grid: `python scripts/thumbnail.py output.pptx`

### From Template
1. Extract text: `python -m markitdown template.pptx`
2. Create thumbnail grid for visual analysis
3. Build template inventory (slide-by-slide, 0-indexed)
4. Map content to template slides, select layouts
5. Rearrange: `python scripts/rearrange.py template.pptx working.pptx 0,34,34,50`
6. Extract shapes: `python scripts/inventory.py working.pptx text-inventory.json`
7. Create replacement JSON with proper paragraph formatting
8. Apply: `python scripts/replace.py working.pptx replacement-text.json output.pptx`
9. Validate thumbnails, fix issues, repeat

### PPTX Editing (OOXML)
1. Read `ooxml.md` for XML structure guidance
2. Unpack: `python ooxml/scripts/unpack.py file.pptx output_dir/`
3. Edit XML files (`ppt/slides/slideN.xml`)
4. Validate: `python ooxml/scripts/validate.py dir/ --original file.pptx`
5. Pack: `python ooxml/scripts/pack.py input_dir/ output.pptx`

### Key Files in PPTX
- `ppt/presentation.xml` — metadata and slide references
- `ppt/slides/slide{N}.xml` — individual slides
- `ppt/notesSlides/notesSlide{N}.xml` — speaker notes
- `ppt/theme/theme1.xml` — colors and fonts
- `ppt/slideLayouts/` — layout templates
- `ppt/media/` — images and media

### Design Principles
- State design approach BEFORE writing code
- Web-safe fonts only: Arial, Helvetica, Georgia, Verdana, Tahoma, Trebuchet MS, Impact, Courier New
- Use content-informed color palettes (see design-system.md for options)
- Two-column layout preferred for charts/tables (never vertical stack)
- Extreme size contrast: 72pt headlines vs 11pt body
- Rasterize gradients/icons as PNG first, then reference in HTML

## Slide Design Best Practices

### Visual Details
- Diagonal section dividers, asymmetric column widths (30/70, 40/60)
- Thick single-color borders on one side, corner brackets
- All-caps headers with wide letter spacing
- Monospace for data/stats, oversized numbers for key metrics
- Full-bleed images with text overlays
- Split backgrounds (two colors, diagonal or vertical)

### Layout Matching
| Content Type | Layout |
|---|---|
| Single topic | Single-column, full-width |
| 2 distinct items | Two-column (40/60 split) |
| 3 distinct items | Three-column |
| Key metric | Full-slide, oversized number |
| Quote | Dedicated quote layout with attribution |
| Image + text | Side-by-side, image > 50% width |

## LaTeX Posters
- Use LaTeX MCP tools for creation/editing
- Scientific poster templates: landscape A0/A1
- Beamerposter package for conference-style
- TikZ for diagrams and visual elements
- Follow institution style guides when provided

## Theme Application
- 10 pre-built themes available in `themes/` directory
- Show `theme-showcase.pdf` for visual preview
- Each theme: color palette (hex codes) + font pairings
- Apply consistently across all slides
- Custom themes: generate from description, review before applying
