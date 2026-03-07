# Scientific Slides Reference

## Overview

Build slide decks for conference talks, seminars, thesis defenses, and professional presentations. Supports PowerPoint and LaTeX Beamer. Emphasizes visual engagement, minimal text, proper citations, and story-driven narrative.

## Design Philosophy

Scientific presentations should be VISUALLY ENGAGING:
- **Compelling visuals**: High-quality figures, images, diagrams (not just bullet points)
- **Research context**: Proper citations establishing credibility
- **Minimal text**: Bullet points as prompts; you explain verbally
- **Professional design**: Modern colors, strong visual hierarchy, generous white space
- **Story-driven**: Clear narrative arc, not just data dumps

## Slide Structure by Talk Duration

| Duration | Total Slides | Intro | Methods | Results | Discussion |
|----------|-------------|-------|---------|---------|-----------|
| 10 min | 10-12 | 2-3 | 2-3 | 4-5 | 2-3 |
| 15 min | 15-18 | 3-4 | 3-4 | 6-7 | 3-4 |
| 20 min | 20-22 | 4-5 | 4-5 | 8-10 | 4-5 |
| 45 min | 40-45 | 8-10 | 8-10 | 15-18 | 8-10 |

Rule of thumb: ~1 slide per minute.

## Slide Design Rules

**Text**:
- Minimum 18pt body text, ideally 24pt+
- Maximum 3-6 bullets per slide
- 5-7 words per bullet
- One main idea per slide

**Visual Design**:
- High contrast (4.5:1 minimum, 7:1 preferred)
- Colorblind-accessible colors
- Consistent design across all slides
- Generous white space
- Professional sans-serif fonts

**Figures**:
- Simplified from paper versions (larger labels, fewer details)
- Large, readable axis labels
- Data visualizations dominate results section (40-50% of slides)

## Required Structural Elements

1. **Title slide**: Authors, affiliation, date
2. **Outline/Overview**: Brief roadmap
3. **Introduction**: Background with 3-5 citations
4. **Research question**: Clearly stated
5. **Methods**: Adequately summarized (not excessive)
6. **Results**: Logical with clear visualizations
7. **Discussion**: Compare with literature (3-5 citations)
8. **Conclusions**: Key findings summary
9. **Acknowledgments/Funding**: At end
10. **Backup slides**: For Q&A (optional)

## Citation Format for Slides

- Use abbreviated format: Author et al., Year
- Place citations in small text (14-16pt) at bottom of slide or near relevant content
- Include 3-5 citations in introduction and discussion sections
- Do not crowd slides with references

## PowerPoint Best Practices

- Use slide masters for consistency
- 16:9 aspect ratio (standard)
- Embed fonts for portability
- Export to PDF for backup

## Beamer (LaTeX) Best Practices

- Use clean themes (metropolis, Madrid)
- `\setbeamerfont{frametitle}{size=\large}`
- Keep frame content within safe margins
- Use `\pause` for progressive reveal

## Common Issues

**Critical** (must fix):
- Text overflow/truncation
- Font too small (<18pt)
- Element overlaps
- Insufficient contrast
- No citations

**Major** (should fix):
- Inconsistent design
- Walls of text
- Cramped layout
- Missing conclusion slide
- Poor color choices

## Timing Guide

- Practice with timer at least 2-3 times
- Leave 2-3 minutes for questions (if expected)
- Mark transition slides for pacing
- Have backup slides for anticipated questions
