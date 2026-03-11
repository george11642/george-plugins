# Scientific Slides Reference

## Overview

Scientific presentations are a critical medium for communicating research. This reference covers conference talks, seminars, thesis defenses, grant pitches, and journal clubs.

**CRITICAL DESIGN PHILOSOPHY**: Avoid dry, text-heavy slides. Great scientific presentations combine:
- **Compelling visuals**: Figures, images, diagrams (not just bullet points)
- **Research context**: Proper citations establishing credibility
- **Minimal text**: Bullet points as prompts, speaker provides explanation verbally
- **Professional design**: Modern color schemes, strong visual hierarchy, generous white space
- **Story-driven**: Clear narrative arc, not data dumps

## Slide Generation with Nano Banana Pro

### Default Workflow: PDF Slides (Recommended)

Generate each slide as a complete image, then combine into PDF.

**Step 1: Plan Each Slide**

Create a detailed plan: title, key points, visual elements per slide.

**Step 2: Generate Each Slide**

**Formatting Consistency Protocol** (include in EVERY prompt):
1. Define a **Formatting Goal**: color scheme, typography, visual style, layout
2. Always **attach the previous slide** with `--attach` for visual continuity
3. Default author is "K-Dense" unless specified
4. Include **citations directly in prompt**: "CITATIONS: Include at bottom: (Author et al., Year)"
5. **Attach existing figures** for results slides

```bash
# Title slide (establishes style)
python scripts/generate_slide_image.py "Title slide: 'Research Title'. Conference, Speaker. FORMATTING GOAL: Dark blue background (#1a237e), white text, gold accents (#ffc107), minimal design, sans-serif." -o slides/01_title.png

# Content slide (attach previous + citations)
python scripts/generate_slide_image.py "Slide titled 'Why This Matters'. Three key points with icons. CITATIONS: (LeCun et al., 2015; Goodfellow et al., 2016). FORMATTING GOAL: Match attached slide style." -o slides/02_intro.png --attach slides/01_title.png

# Results slide (attach data figures)
python scripts/generate_slide_image.py "Slide titled 'Results'. Present attached chart. Key findings highlighted. FORMATTING GOAL: Match attached slide style." -o slides/04_results.png --attach slides/03.png --attach figures/chart.png
```

**Step 3: Combine to PDF**
```bash
python scripts/slides_to_pdf.py slides/*.png -o presentation.pdf
```

### PPT Workflow: PowerPoint with Generated Visuals

1. Generate visuals with `--visual-only` flag
2. Build PPTX using pptx skill or python-pptx
3. Add text separately

```bash
python scripts/generate_slide_image.py "Professional diagram of ML pipeline..." -o figures/pipeline.png --visual-only
```

### LaTeX Beamer Workflow

Best for mathematical content, version control, consistent formatting.

Templates: `scientific-slides/assets/beamer_template_{conference,seminar,defense}.tex`

## Presentation Structure

**Universal Story Arc**:
1. **Hook**: Grab attention (30-60 sec)
2. **Context**: Establish importance (5-10%)
3. **Problem/Gap**: What's unknown (5-10%)
4. **Approach**: Your solution (15-25%)
5. **Results**: Key findings (40-50%)
6. **Implications**: Meaning (15-20%)
7. **Closure**: Memorable conclusion (1-2 min)

**Talk-Specific Structures**:

| Type | Duration | Focus | Slides |
|------|----------|-------|--------|
| Conference | 10-20 min | 1-2 findings, minimal methods | 10-20 |
| Seminar | 45-60 min | Comprehensive, detailed methods | 40-55 |
| Defense | 45-60 min | Complete dissertation overview | 45-60 |
| Grant pitch | 10-20 min | Significance, feasibility, impact | 10-20 |
| Journal club | 20-45 min | Critical analysis of paper | 20-40 |

## Slide Design Principles

**Visual-First Approach** (CRITICAL):
- Start with visuals, add text as support
- Every slide needs STRONG visual element
- Target: 60-70% visual, 30-40% text

**Typography**:
- Sans-serif fonts (Arial, Calibri, Helvetica)
- 24-28pt body text, 36-44pt titles
- High contrast: 7:1 preferred, 4.5:1 minimum

**Color**:
- Modern palettes matching your topic
- 3-5 colors total, high contrast, color-blind safe

**Layout**:
- Vary layouts (two-column, full-figure, text-overlay)
- Rule of thirds for focal points
- 40-50% white space

**Anti-patterns**:
- Walls of text (>6 bullets)
- Small fonts (<24pt body)
- Default themes without customization
- All slides identical layout
- Missing citations

## Data Visualization for Slides

**Key differences from journal figures**:
- Simplify, don't replicate
- Larger fonts (18-24pt minimum)
- Fewer panels (split across slides)
- Direct labeling (not legends)
- Progressive disclosure for complex data

## Timing and Pacing

**One-Slide-Per-Minute Rule** (adjust for complexity):
- Introduction: 15-20%
- Methods: 15-20%
- Results: 40-50% (MOST TIME)
- Discussion: 15-20%
- Conclusion: 5%

**Practice requirements**: 3-5 times minimum with timer.

**15-min talk checkpoints**: 3-4 min (finishing intro), 7-8 min (mid-results), 12-13 min (conclusions).

## Visual Validation Workflow

1. Generate PDF
2. Convert to images: `python scripts/pdf_to_images.py presentation.pdf review/slide --dpi 150`
3. Check each slide: text overflow, element overlap, font size, contrast, alignment
4. Document issues, fix, re-validate

**Stopping criteria**: No overflow, no overlap, all text readable (>=18pt), adequate contrast, professional appearance.

## Quick Start: 15-Minute Conference Talk

1. **Research & Plan** (45 min): Find 8-12 papers, outline 15-18 slides
2. **Generate Slides** (1-2 hrs): Consistent formatting, attach previous slides, include citations
3. **Review & Iterate** (30 min): Visual inspection, regenerate problem slides
4. **Practice** (2-3 hrs): 3-5 times with timer, prepare for questions
5. **Finalize** (30 min): Backup slides, save multiple copies

## Scripts Reference

| Script | Purpose | Key Options |
|--------|---------|-------------|
| `generate_slide_image.py` | Generate slides/visuals | `-o`, `--attach`, `--visual-only`, `--iterations` |
| `slides_to_pdf.py` | Combine images to PDF | `-o`, `--dpi` |
| `validate_presentation.py` | Check slide count/size | `--duration` |
| `pdf_to_images.py` | PDF to images for review | `--dpi` |

## Key Principles Summary

1. Visual-first: every slide needs strong visual element
2. Research-backed: cite 8-15 papers (3-5 intro, 3-5 discussion)
3. Modern aesthetics: contemporary palette, not defaults
4. Minimal text: 3-4 bullets, 4-6 words each, 24-28pt
5. Story arc: spend 40-50% on results
6. High contrast: 7:1 preferred
7. Varied layouts: not all bullet lists
8. Practice 3-5 times, ~1 slide per minute
9. Visual review to catch overflow and overlap
10. 40-50% white space per slide
