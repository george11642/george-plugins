# Scientific Schematics Reference

## Overview

Generate publication-quality scientific diagrams using Gemini MCP tools with iterative quality refinement. Supports neural network architectures, biological pathways, CONSORT/PRISMA flowcharts, system diagrams, circuit schematics, and conceptual frameworks.

## How It Works

1. Describe your diagram in natural language
2. `mcp__gemini__gemini_image` generates the initial image
3. `mcp__gemini__gemini_analyze` reviews quality against document-type threshold
4. If quality >= threshold: DONE (early stop)
5. If below threshold: refine via `mcp__gemini__gemini_image_edit`, re-review
6. Repeat until quality met or max iterations reached

## Quality Thresholds by Document Type

| Document Type | Threshold | Description |
|---------------|-----------|-------------|
| journal | 8.5/10 | Nature, Science, peer-reviewed journals |
| conference | 8.0/10 | Conference papers |
| thesis | 8.0/10 | Dissertations, theses |
| grant | 8.0/10 | Grant proposals |
| preprint | 7.5/10 | arXiv, bioRxiv |
| report | 7.5/10 | Technical reports |
| poster | 7.0/10 | Academic posters |
| presentation | 6.5/10 | Slides, talks |

## Quality Scoring Criteria (0-2 each, total /10)

1. **Scientific Accuracy** -- correct concepts, notation, relationships
2. **Clarity and Readability** -- easy to understand, clear hierarchy
3. **Label Quality** -- complete, readable, consistent labels
4. **Layout and Composition** -- logical flow, balanced, no overlaps
5. **Professional Appearance** -- publication-ready quality

## MCP Tool Workflow

```
# Step 1: Generate initial image
mcp__gemini__gemini_image with detailed prompt

# Step 2: Analyze quality
mcp__gemini__gemini_analyze scoring against criteria

# Step 3: If score < threshold, refine
mcp__gemini__gemini_image_edit with improvement instructions

# Repeat until threshold met or max iterations
```

For draft/fast iteration, use `mcp__gemini__gemini_image_fast` initially.

## Effective Prompt Guidelines

**Good prompts** (specific, detailed):
- "CONSORT flowchart showing participant flow from screening (n=500) through randomization to final analysis"
- "Transformer encoder-decoder architecture with multi-head attention and cross-attention connections"
- "MAPK signaling cascade: EGFR -> RAS -> RAF -> MEK -> ERK -> nucleus, with phosphorylation steps labeled"

**Key elements to include**: diagram type, specific components, flow direction, labels, style requirements

**Avoid vague prompts**: "Make a flowchart" or "Neural network" without specifics

## Scientific Quality Standards (Auto-Applied)

- Clean white/light background
- High contrast for readability
- Clear, readable labels (minimum 10pt)
- Professional sans-serif fonts
- Colorblind-friendly colors (Okabe-Ito palette)
- Proper spacing, scale bars, legends where appropriate

## Legacy Script Usage

```bash
python scripts/generate_schematic.py "diagram description" -o figures/output.png
python scripts/generate_schematic.py "diagram" -o out.png --doc-type journal
python scripts/generate_schematic.py "diagram" -o out.png --iterations 2
```

## Diagram Types

- Study design flowcharts (CONSORT, PRISMA, STROBE)
- Neural network architectures (Transformer, CNN, RNN)
- Biological pathways and molecular interactions
- System architecture and data flow diagrams
- Circuit diagrams and electrical schematics
- Conceptual framework diagrams
- Algorithm flowcharts and decision trees
- Network topologies and hierarchical structures

## Technical Requirements

- **Resolution**: Vector preferred, or 300+ DPI raster
- **Format**: PDF for LaTeX, SVG for web, PNG as fallback
- **Line weights**: Minimum 0.5pt, typical 1-2pt
- **Text size**: 7-8pt minimum at final size

## Integration

- Include in LaTeX with `\includegraphics{}`
- Write comprehensive captions with all abbreviations defined
- Reference in text narrative
- Maintain consistent style across all figures
- Version control prompts and generated images
