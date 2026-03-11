---
name: presentations-docs
description: "Use when creating presentations, slide decks, posters, or document generation. Triggers on presentation, slides, slide deck, make slides, create a deck, poster, conference talk, thesis defense, keynote, seminar, PPTX, PowerPoint, LaTeX poster, Beamer, paper to web, template, OOXML, theme, color palette, speaker notes, storyboard, narrative arc, bento grid, layout pattern, 9:16, vertical slides, mobile presentation, WCAG slides, accessible presentation, data visualization for slides, chart for slides."
metadata:
  version: 1.0.0
---

# Presentations & Documents

Route presentation, poster, and document tasks to the correct reference. Read all relevant references — most tasks span format + design + content.

## Task Router

| Task | Reference | Notes |
|------|-----------|-------|
| Slide deck, conference talk, seminar, thesis defense | [references/slides.md](references/slides.md) | Default: PDF via Nano Banana Pro |
| Research/conference/A0 poster, LaTeX poster | [references/latex-posters.md](references/latex-posters.md) | Default for poster requests |
| PPTX poster, PowerPoint poster | [references/pptx.md](references/pptx.md) | Only when PPTX explicitly requested |
| PowerPoint presentations from scratch | [references/pptx.md](references/pptx.md) | html2pptx or OOXML editing |
| PowerPoint template workflows | [references/pptx-templates.md](references/pptx-templates.md) | thumbnail, rearrange, inventory, replace |
| Theme selection, color palette, styled presentation | [references/theme-factory.md](references/theme-factory.md) | 10 pre-built themes with hex codes |
| Color palette design, color psychology | [references/color-palette-design.md](references/color-palette-design.md) | 18 curated palettes, 5-step methodology |
| Convert paper to website/video/poster | [references/paper-to-web.md](references/paper-to-web.md) | Paper2All pipeline |
| Layout patterns, bento grid, geometric shapes | [references/layout-patterns.md](references/layout-patterns.md) | Diagonal dividers, Z/F-pattern, bento HTML |
| Accessibility, WCAG, color-blind, inclusive design | [references/accessibility-inclusive-design.md](references/accessibility-inclusive-design.md) | WCAG AA/AAA, Okabe-Ito palette, testing |
| Vertical slides, 9:16, mobile presentations | [references/mobile-presentations.md](references/mobile-presentations.md) | 1080x1920px specs, python-pptx 9:16 setup |
| Data visualization for slides, chart selection | [references/data-visualization-2026.md](references/data-visualization-2026.md) | Chart types, anti-patterns, styling rules |
| Storyboarding, narrative arc, story structure | [references/narrative-storyboarding.md](references/narrative-storyboarding.md) | Arc template with timing, slide beats |

**Defaults**: "poster" without format -> LaTeX. "Presentation" without format -> PDF slides. "Use this template" -> pptx-templates workflow.

## Shared Principles

- **Visual-first**: Plan visuals first, generate, review at reduced scale, then assemble. Target 60-70% visual content, 30-40% text.
- **Content limits**: Poster 300-800 words, slides ~50 words/slide. Body text 24pt+, titles 32pt+.
- **Quality gates**: No text overflow, 4.5:1 contrast minimum, max 6 lines per slide, 20%+ whitespace.
- **Validation**: Generate -> convert to images -> inspect overflow/overlap/font/contrast -> fix (max 2 iterations).
- **Speaker notes**: Add for every slide. 1-2 min/slide, 2-3 bullet points, bridge sentences.

## Poster Graphics Requirements

Every poster graphic prompt must include:
- Max 3-4 elements (3 is ideal), max 10 words total
- Giant bold text (80pt+ labels, 120pt+ key numbers)
- High contrast only, 50% white space minimum
- Reject if: 5+ items, 5+ workflow stages, 4+ methods compared

## Layer 3 Skills

- `presentations` — Full presentation reference with all workflows, scripts, tools, and implementation details
