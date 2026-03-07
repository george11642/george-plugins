# Peer Review Reference

## Overview

Structured manuscript evaluation covering methodology, statistics, design, reproducibility, ethics, and reporting standards. Produces hierarchical feedback with constructive, actionable suggestions.

## Review Workflow

### Stage 1: Initial Assessment
- Central research question/hypothesis?
- Main findings and conclusions?
- Scientifically sound and significant?
- Appropriate for intended venue?
- Any immediate major flaws?

Output: 2-3 sentence summary with initial impression.

### Stage 2: Section-by-Section Review

**Abstract/Title**: Accuracy, clarity, completeness, accessibility
**Introduction**: Context, rationale, novelty, literature, objectives
**Methods**: Reproducibility, rigor, detail, ethics, statistics, validation
**Results**: Presentation, figures/tables, statistics, objectivity, completeness
**Discussion**: Interpretation, limitations, context, speculation vs. data, significance
**References**: Completeness, currency, balance, accuracy

### Stage 3: Methodological and Statistical Rigor
- Statistical assumptions met?
- Effect sizes reported alongside p-values?
- Multiple testing correction applied?
- Sample size justified with power analysis?
- Controls appropriate and adequate?
- Replication sufficient?
- Confounders identified and controlled?

### Stage 4: Reproducibility and Transparency
- Raw data deposited? Code available?
- Protocols detailed sufficiently?
- Reporting guidelines followed (CONSORT, PRISMA, etc.)?

### Stage 5: Figure and Data Presentation
- High resolution, clearly labeled, error bars defined?
- Signs of image manipulation?
- Can figures stand alone with legends?

### Stage 6: Ethical Considerations
- IRB/IACUC approval documented?
- Consent, privacy, competing interests disclosed?
- Research integrity concerns?

### Stage 7: Writing Quality
- Logical organization and flow?
- Clear, precise, concise language?
- Accessible to non-specialists?

## Structuring Review Reports

### Summary Statement (1-2 paragraphs)
- Brief synopsis
- Recommendation: accept / minor revisions / major revisions / reject
- 2-3 key strengths, 2-3 key weaknesses

### Major Comments (numbered)
Critical issues affecting validity. For each:
1. State the issue
2. Explain why problematic
3. Suggest specific solutions
4. Indicate if essential for publication

### Minor Comments (numbered)
Less critical improvements. Include specific location, issue, and suggestion.

### Questions for Authors
Methodological details needing clarification, contradictions, missing information.

## Tone Guidelines
- Be constructive, specific, balanced, respectful, objective
- Avoid personal attacks, sarcasm, vague criticism
- Frame criticism as improvement opportunities
- Focus on science, not scientists

## Presentation Review (CRITICAL)

**NEVER read presentation PDFs directly.** Always convert to images first:
```bash
python skills/scientific-slides/scripts/pdf_to_images.py presentation.pdf review/slide --dpi 150
```
Then inspect each slide image for: text overflow, element overlaps, font sizes, contrast, content quality, structure/flow.

## Red Flags to Identify
- Overstated conclusions
- Causal claims from correlational data
- Selective reporting
- Ignoring contradictory evidence
- P-hacking or HARKing
- Image manipulation
- Excessive self-citation
