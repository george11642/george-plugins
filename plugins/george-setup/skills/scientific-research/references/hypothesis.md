# Hypothesis Generation Reference

## Overview

Systematic hypothesis formulation from observations. Generate evidence-based, testable hypotheses with predictions, propose mechanisms, and design experiments.

## Workflow

### 1. Understand the Phenomenon
- Identify core observation or pattern
- Define scope and boundaries
- Clarify known vs. uncertain aspects
- Identify relevant scientific domain(s)

### 2. Literature Search
- **Biomedical**: WebFetch with PubMed URLs for reviews, meta-analyses, primary research
- **All domains**: WebSearch for papers, preprints, established theories
- Look for contradictory findings, unresolved debates, analogous systems

### 3. Synthesize Evidence
- Summarize current understanding
- Identify established mechanisms/theories
- Note conflicting evidence and gaps
- Recognize cross-domain analogies

### 4. Generate Competing Hypotheses (3-5)
Each hypothesis should:
- Provide mechanistic explanation (how/why, not just what)
- Be distinguishable from other hypotheses
- Draw on literature evidence
- Consider multiple levels of explanation

**Strategies**: Apply known mechanisms from analogous systems, consider multiple causative pathways, explore different scales, question assumptions, combine mechanisms in novel ways.

### 5. Evaluate Quality

| Criterion | Question |
|-----------|----------|
| Testability | Can it be empirically tested? |
| Falsifiability | What would disprove it? |
| Parsimony | Simplest explanation fitting evidence? |
| Explanatory Power | How much does it explain? |
| Scope | What range of observations does it cover? |
| Consistency | Aligns with established principles? |
| Novelty | Offers new insights? |

### 6. Design Experimental Tests
For each viable hypothesis:
- What to measure/observe
- Comparisons and controls needed
- Methods and techniques
- Sample sizes and statistical approaches
- Potential confounds and mitigation

Consider: lab experiments, observational studies, clinical trials, natural experiments, computational approaches.

### 7. Formulate Testable Predictions
- Specific, quantitative predictions per hypothesis
- Expected direction and magnitude of effects
- Conditions under which predictions hold
- Predictions that distinguish between competing hypotheses
- Predictions that would falsify the hypothesis

### 8. Report Structure

**LaTeX report with colored boxes:**
- **Main text** (4 pages max): Executive summary, competing hypotheses (each in colored box), testable predictions, critical comparisons
- **Appendices** (comprehensive): Literature review, experimental designs, quality assessment, supplementary evidence

**Box Types**: hypothesisbox1-5 (blue/green/purple/teal/orange), predictionbox (amber), comparisonbox (gray), evidencebox (light blue), summarybox (blue)

**Overflow Prevention**: Use `\newpage` before each hypothesis box. Keep each box to 0.6 pages max. Move details to appendices.

**Citations**: 10-15 key citations in main text, 40-70+ comprehensive in appendices, 50+ total target.

## Quality Standards
- Evidence-based with citations
- Testable with measurable predictions
- Mechanistic explanations (not descriptions)
- Comprehensive alternative explanations
- Rigorous experimental designs
