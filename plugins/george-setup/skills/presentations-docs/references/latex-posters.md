# LaTeX Research Posters Reference

## Overview

Research posters for conferences, symposia, and academic events using LaTeX packages: beamerposter, tikzposter, or baposter.

## When to Use

Default for all poster requests unless PPTX/PowerPoint explicitly requested.

Use for: conference posters, thesis defense posters, public engagement summaries, department templates, complex multi-column layouts, integration with equations/citations.

## LaTeX Package Selection

| Package | Best For | Strengths |
|---------|----------|-----------|
| **tikzposter** | Modern, colorful designs | Flexible, easy customization, good defaults |
| **baposter** | Structured professional layouts | Precise column control, header boxes |
| **beamerposter** | Institutional themes | Beamer familiarity, theme support |

## AI-Powered Visual Generation

**STANDARD WORKFLOW**: Generate ALL visuals before creating LaTeX poster.

**Target**: 60-70% visuals, 30-40% text.

### MANDATORY Poster Graphic Requirements

Every prompt must include:
```
POSTER FORMAT REQUIREMENTS (STRICTLY ENFORCE):
- ABSOLUTE MAXIMUM 3-4 elements per graphic (3 is ideal)
- ABSOLUTE MAXIMUM 10 words total
- ALL text GIANT BOLD (80pt+ labels, 120pt+ key numbers)
- High contrast ONLY (dark on white OR white on dark)
- MANDATORY 50% white space minimum
- Thick lines (5px+), large icons (200px+)
- ONE SINGLE MESSAGE per graphic
```

### Content Limits Per Graphic Type

| Type | Max Elements | Max Words | Reject If |
|------|-------------|-----------|-----------|
| Flowchart | 3-4 boxes | 8 words | 5+ stages, nested steps |
| Key findings | 3 items | 9 words | 4+ metrics, paragraphs |
| Comparison | 3 bars | 6 words | 4+ methods, legend text |
| Case study | 1 case, 3 elements | 6 words | Multiple cases |
| Timeline | 3-4 points | 8 words | Year-by-year detail |

### Pre-Generation Review (MANDATORY)

For each planned graphic:
1. Can describe in 3-4 items or less? (NO -> simplify/split)
2. Multi-stage workflow 5+ steps? (YES -> flatten to 3-4)
3. All text in 10 words or less? (NO -> cut text)
4. Conveys ONE clear message? (NO -> split)

**Always reject**: "7-stage workflow", "multiple case studies in one", "timeline 2015-2024 annual", "comparison of 6 methods".

### Generation Examples

```bash
mkdir -p figures

# Workflow - 3 mega-stages only
python scripts/generate_schematic.py "POSTER FORMAT for A0. ULTRA-SIMPLE 3-box workflow: 'DISCOVER' -> 'VALIDATE' -> 'APPROVE'. Each 120pt+ bold. Thick arrows. 60% white space. 3 words only." -o figures/workflow.png

# Results - 2-3 bars only
python scripts/generate_schematic.py "POSTER FORMAT for A0. SIMPLE bar chart ONLY 3 bars: BASELINE (70%), EXISTING (85%), OURS (95%). GIANT percentages ON bars (120pt+). NO axis, NO legend. 50% white space." -o figures/results.png

# Key findings - exactly 3 cards
python scripts/generate_schematic.py "POSTER FORMAT for A0. EXACTLY 3 cards: '95%' (150pt) 'ACCURACY' (60pt), '2X' (150pt) 'FASTER' (60pt), checkmark 'VALIDATED' (60pt). 50% white space." -o figures/conclusions.png
```

### Post-Generation Review (MANDATORY)

View each figure at 25% zoom:

**PASS** (all must be true): Can read all text, 3-4 elements max, 50%+ white space, understand in 2 seconds.

**FAIL** (regenerate if any true): Small text -> "150pt+", >4 elements -> "ONLY 3 elements", <50% white space -> "60% white space", complex workflow -> split into 2-3 graphics.

## Preventing Content Overflow

1. **Max 5-6 sections** for A0 (Title, Intro, Methods, Results, Conclusions)
2. **Safe margins**: `margin=25mm` for tikzposter, `colspacing=2em` for baposter
3. **Figure sizing**: `width=0.85\linewidth` (NEVER 1.0)
4. **Word limits**: 50-100 per section, 300-800 total
5. **Check overflow**: `grep -i "overfull" poster.log`

## LaTeX Templates

### tikzposter
```latex
\documentclass[25pt, a0paper, portrait, margin=25mm]{tikzposter}

\begin{document}
\maketitle
\begin{columns}
\column{0.5}
\block{Introduction}{
  \centering
  \includegraphics[width=0.85\linewidth]{figures/intro.png}
  \vspace{0.5em}
  Brief context (2-3 sentences).
}
\block{Methods}{
  \centering
  \includegraphics[width=0.9\linewidth]{figures/methods.png}
}
\column{0.5}
\block{Results}{
  \centering
  \includegraphics[width=0.9\linewidth]{figures/results.png}
  \vspace{0.5em}
  Key findings in 3-4 bullets.
}
\block{Conclusions}{
  \centering
  \includegraphics[width=0.8\linewidth]{figures/conclusions.png}
}
\end{columns}
\end{document}
```

### baposter
```latex
\headerbox{Methods}{name=methods,column=0,row=0}{
  \centering
  \includegraphics[width=0.95\linewidth]{figures/methods.png}
}
\headerbox{Results}{name=results,column=1,row=0}{
  \includegraphics[width=\linewidth]{figures/results.png}
  \vspace{0.3em}
  Key finding: Our method achieves 92% accuracy.
}
```

## Font Size Reference

| Element | Size | Readable From |
|---------|------|---------------|
| Title | 72pt+ | 10+ feet |
| Section headers | 48-72pt | 8+ feet |
| Body text | 24-36pt | 4-6 feet |
| References | 18-24pt | 2-3 feet |
| AI graphic labels | 80pt+ | 6-8 feet |
| AI graphic numbers | 120pt+ | 10+ feet |

## Quality Checklist

### PDF Overflow Check
```bash
pdflatex poster.tex
grep -i "overfull" poster.log
```

Open at 100% zoom and check all 4 edges + between columns for:
- Text cut off
- Content touching boundaries
- Figures bleeding off edges

**Fix hierarchy**: Simplify AI graphics -> reduce sections -> cut text -> reduce figure width -> increase margins.

### Visual Inspection
- [ ] Content fills page (no large white margins)
- [ ] Consistent spacing between columns/blocks
- [ ] No overlapping text or figures
- [ ] Title visible and large (72pt+)
- [ ] Body text readable (24-36pt)
- [ ] All figures display correctly, not pixelated
- [ ] Colors render as expected
- [ ] All citations resolved (no [?])
- [ ] No placeholder text remaining

### Pre-Print
- [ ] All fonts embedded: `pdffonts poster.pdf`
- [ ] Images 300+ DPI: `pdfimages -list poster.pdf`
- [ ] File size reasonable (<50MB for email)
- [ ] Test print at 25% scale
- [ ] Color contrast >= 4.5:1

## Common Poster Content Patterns

**Experimental**: Title > Intro/Hypothesis > Methods (diagram) > Results (2-4 figures) > Conclusions > References

**Computational**: Title > Motivation > Approach (flowchart) > Implementation > Results (metrics) > Applications > Code QR > References

**Review/Survey**: Title > Scope > Search Strategy > Key Findings (by category) > Trends > Gaps > Conclusions > References

## Accessibility

- Avoid red-green combinations
- Use patterns/shapes in addition to color
- Minimum 24pt body text
- High contrast (WCAG AA: 4.5:1 minimum)
- Clear, concise language; define acronyms

## Compilation

```bash
# Standard
pdflatex poster.tex

# Better font support
lualatex poster.tex

# Font embedding verification
pdffonts poster.pdf

# File size optimization
gs -sDEVICE=pdfwrite -dPDFSETTINGS=/printer -dNOPAUSE -dQUIET -dBATCH -sOutputFile=poster_compressed.pdf poster.pdf
```
