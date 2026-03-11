---
name: scientific-research
description: Use for scientific research, academic writing, statistical analysis, grant proposals, peer review, IRB/ethics, causal inference (DAGitty, DAGs), and PRISMA/CONSORT methodology diagrams. Covers manuscripts, LaTeX, BibTeX, p-value, ANOVA, power analysis, effect size, NSF/NIH/DOE grants, systematic reviews, meta-analysis, thematic analysis, preregistration, OSF, FAIR data, propensity scores, instrumental variables, SEM/CFA, lavaan, lme4, qualitative research, science communication.
license: MIT license
metadata:
    skill-author: K-Dense Inc.
---

# Scientific Research

## Overview

Master skill for all scientific research workflows. Covers the full research lifecycle: literature reviews, hypothesis generation, statistical analysis, manuscript writing, figure creation, scientific diagrams, presentation slides, citation management, peer review, and grant proposals.

Each domain has a dedicated reference file with detailed guidance. This skill routes you to the right reference based on your intent.

## Task Router

| Intent | Reference File | When to Use |
|--------|---------------|-------------|
| Writing papers, manuscripts, IMRAD structure | `references/writing.md` | Drafting or revising any section; also cover letters and rebuttals |
| Creating publication figures, plots | `references/visualization.md` | Journal-ready plots; also multi-panel layouts and supplementary figures |
| Scientific diagrams, schematics, flowcharts | `references/schematics.md` | AI-generated diagrams via Gemini; also graphical abstracts |
| Presentation slides, conference talks | `references/slides.md` | PowerPoint/Beamer decks; also poster talks and thesis defenses |
| Literature reviews, systematic reviews | `references/literature-review.md` | Multi-database search + PRISMA; also scoping and narrative reviews |
| Hypothesis generation, experimental design | `references/hypothesis.md` | Competing hypotheses with predictions; also power/sample-size planning |
| Citation management, BibTeX, DOI lookup | `references/citations.md` | Search, validate, deduplicate; also format conversion between styles |
| Peer review, manuscript evaluation | `references/peer-review.md` | Structured review with major/minor comments; also rebuttal responses |
| Grant proposals (NSF, NIH, DOE, DARPA, NSTC) | `references/grants.md` | Full proposals; also LOIs, budget justifications, and resubmissions |
| Statistical tests, power analysis, reporting | `references/statistics.md` | Test selection + APA reporting; also Bayesian analysis and meta-analysis |
| Qualitative methods, thematic analysis, interviews | `references/qualitative-research.md` | Reflexive TA 6-phase process; also grounded theory, phenomenology, mixed methods |
| Open science, preregistration, reproducibility | `references/open-science.md` | OSF workflow, registered reports, FAIR data, open code, reproducibility checklists |
| Research ethics, IRB, decolonial methodology | `references/research-ethics.md` | Belmont principles, CBPR, OCAP, CRediT authorship, data privacy (GDPR) |
| Data management, FAIR principles, DMPs | `references/data-management.md` | NSF/NIH DMP requirements, metadata standards, versioning (DVC), repository selection |
| Causal inference, DAGs, multilevel models, SEM | `references/advanced-statistics.md` | DAGitty, propensity scores, IV, DiD, lme4, lavaan; also causal ML |
| Science communication, policy briefs, public engagement | `references/research-communication.md` | Policy briefs, press releases, social media threads, video abstracts, graphical abstracts |

## Before Starting

Gather these answers before any research task — they determine which references to load and how to calibrate output:

1. **Discipline?** (e.g., biomedical, social science, engineering, ecology) — drives terminology, citation style, reporting guidelines
2. **Research stage?** (literature review, hypothesis, data collection, analysis, writing, revision) — determines workflow entry point
3. **Output format?** (journal manuscript, grant proposal, conference slides, poster, thesis chapter) — sets quality thresholds and structure
4. **Target venue?** (Nature, PNAS, field-specific journal, NSF, NIH) — dictates formatting, word limits, figure specs
5. **Data type?** (continuous, categorical, mixed, qualitative) — guides statistical test selection

## Quick Reference

**Statistical Test Selector** (most common cases):
- 2 groups, normal → independent t-test | non-normal → Mann-Whitney U
- 3+ groups, normal → one-way ANOVA | non-normal → Kruskal-Wallis
- Outcome prediction → linear regression (continuous) | logistic regression (binary)
- Association → Pearson r (normal) | Spearman rho (non-normal)

**Citation Format by Field**:
- Social sciences → APA `(Author, Year)` | Medicine → AMA superscript | Biomedical → Vancouver `[1]` | Engineering/CS → IEEE `[1]`

**Reporting Guideline Selector**:
- RCT → CONSORT | Observational → STROBE | Systematic review → PRISMA | Animal → ARRIVE | Prediction model → TRIPOD

## Cross-Cutting Principles

### Visual Enhancement (All Documents)

Every scientific document should include AI-generated figures. Use the schematics workflow (see `references/schematics.md`) to generate diagrams via Gemini MCP tools:

- **Papers**: Graphical abstract + 5-8 figures minimum
- **Literature reviews**: PRISMA flow diagram + thematic synthesis diagrams
- **Grant proposals**: Methodology flowchart + timeline/Gantt chart
- **Presentations**: 1-2 visuals per slide
- **Hypothesis reports**: Framework diagram + experimental design flowchart

### Writing Style

- **Always write in full paragraphs** for manuscripts -- never submit bullet points in final text
- Use two-stage process: (1) outline with key points, (2) convert to flowing prose
- Match field-specific terminology to discipline and target journal
- Follow IMRAD structure unless venue requires otherwise

### Citation Rigor

- Verify all DOIs before submission using validation scripts
- Prioritize high-impact papers (Tier 1 venues, high citation counts)
- Use consistent citation style throughout (APA, Vancouver, Nature, etc.)
- Run metadata enrichment on incomplete BibTeX entries

### Statistical Standards

- Always check assumptions before running tests
- Report effect sizes with confidence intervals alongside p-values
- Distinguish statistical from practical significance
- Pre-register analyses when possible

### Reproducibility

- Document all methods with enough detail for replication
- Share code and data via repositories
- Follow reporting guidelines (CONSORT, STROBE, PRISMA, ARRIVE)
- Version-control all source files and generated figures

## Domain Summaries

### Scientific Writing

Write manuscripts using IMRAD structure with proper citations, figures, and reporting guidelines. Two-stage process: outline first, then convert to prose. Example: for a Nature submission, use Vancouver citations, 3000-word limit, structured abstract, and 6-8 display items. See `references/writing.md`.

### Scientific Visualization

Create publication-ready figures with multi-panel layouts, error bars, significance markers, and colorblind-safe palettes. Export as PDF/EPS/TIFF. Example: Nature requires 89mm (single column) or 183mm (double) width at 300+ DPI. See `references/visualization.md`.

### Scientific Schematics

Generate publication-quality diagrams using Gemini MCP tools with iterative quality refinement. Supports neural network architectures, biological pathways, CONSORT/PRISMA flowcharts, system diagrams, and circuit schematics. Quality thresholds vary by document type (6.5-8.5/10). See `references/schematics.md`.

### Scientific Slides

Build slide decks for conference talks, seminars, and defenses. Supports PowerPoint and LaTeX Beamer. Emphasizes visual engagement, minimal text, proper citations, and story-driven narrative. Slide count targets ~1 per minute. See `references/slides.md`.

### Literature Review

Conduct systematic, multi-database literature reviews (PubMed, arXiv, bioRxiv, Semantic Scholar). Use PICO framework for clinical reviews (e.g., P: Type 2 diabetes patients, I: GLP-1 agonists, C: metformin, O: HbA1c reduction). Phases: planning, search, screening, extraction, synthesis. See `references/literature-review.md`.

### Hypothesis Generation

Systematic hypothesis formulation from observations. Generate 3-5 competing hypotheses, evaluate against quality criteria (testability, falsifiability, parsimony), design experimental tests, formulate quantitative predictions. LaTeX report output with colored boxes. See `references/hypothesis.md`.

### Citation Management

Search Google Scholar and PubMed, extract metadata from DOI/PMID/arXiv, validate BibTeX entries, format and deduplicate bibliographies. Scripts for automated search, extraction, validation, and formatting. See `references/citations.md`.

### Peer Review

Structured manuscript evaluation: initial assessment, section-by-section review, methodological rigor, reproducibility, figure integrity, ethical considerations, writing quality. Hierarchical feedback with major/minor comments. Presentation review via image-based inspection. See `references/peer-review.md`.

### Research Grants

Write competitive proposals for NSF, NIH, DOE, DARPA, and Taiwan NSTC. Agency-specific formatting, review criteria, budget preparation, broader impacts, specific aims, timeline planning, and resubmission strategies. See `references/grants.md`.

### Statistical Analysis

Guided test selection, assumption checking, power analysis, effect sizes, and APA reporting. Example output: "t(98)=3.82, p<.001, d=0.77, 95% CI [0.36, 1.18]". Always check assumptions first, report effect sizes with CIs, and use non-parametric alternatives when normality is violated. See `references/statistics.md`.

### Qualitative Research

Conduct rigorous qualitative studies using Reflexive Thematic Analysis (Braun & Clarke 6-phase), Grounded Theory (theoretical sampling, constant comparison, saturation), and interview design. Quality criteria: credibility, transferability, dependability, confirmability. Tools: NVivo, ATLAS.ti, Taguette. Mixed methods integration. See `references/qualitative-research.md`.

### Open Science

Implement preregistration via OSF or AsPredicted, write Registered Reports, share data under FAIR principles, and deposit code with Zenodo DOIs. Discipline-specific reproducibility checklists (psychology, biomedical, computational). Open practice badges. See `references/open-science.md`.

### Research Ethics

Navigate IRB review levels, design valid informed consent, apply CBPR and OCAP principles for community and Indigenous research, and embed decolonial reflexivity. CRediT authorship taxonomy, conflict of interest disclosure, GDPR data privacy for research. See `references/research-ethics.md`.

### Data Management

Write NSF and NIH Data Management Plans, implement FAIR principles with appropriate metadata standards (Dublin Core, DataCite, EML, BIDS), version data with DVC or Git LFS, and select the right repository (Zenodo, Dryad, ICPSR, discipline-specific). License selection: CC0 vs CC BY. See `references/data-management.md`.

### Advanced Statistics

Causal inference with DAGs (DAGitty, backdoor criterion, collider bias), propensity scores, IV, RDD, and DiD. Multilevel models (lme4/statsmodels, ICC, random slopes). Longitudinal analysis and multiple imputation. SEM/CFA with lavaan/semopy (CFI, RMSEA, SRMR). Prediction vs causal model distinction; Double ML and causal forests. See `references/advanced-statistics.md`.

### Research Communication

Translate findings for non-academic audiences: 1-2 page policy briefs with numbered recommendations, press releases with inverted-pyramid structure, Twitter/X 10-tweet threads, video abstracts (90-second structure), and graphical abstracts. Altmetric tracking. Audience analysis, curse of knowledge, analogy and metaphor. See `references/research-communication.md`.

## Integration Notes

These domains work together in research workflows:

- **Literature review** feeds **hypothesis generation** and **writing** (introduction/discussion)
- **Statistical analysis** produces results reported in **writing** and visualized via **visualization**
- **Schematics** generates diagrams for **writing**, **slides**, **grants**, and **literature reviews**
- **Citation management** supports **writing**, **literature review**, and **grants**
- **Peer review** evaluates manuscripts produced by **writing** and **visualization**
- **Slides** presents findings from all other domains

## Layer 3 Skills

These atomic skills provide deeper specialization within the scientific research domain:

| Skill | Use when |
|-------|----------|
| `writing` | IMRAD manuscripts, cover letters, rebuttals |
| `visualization` | Publication-quality figures, multi-panel layouts |
| `schematics` | AI-generated diagrams via Gemini, graphical abstracts |
| `slides` | Conference talks, PowerPoint/Beamer decks |
| `literature-review` | Systematic reviews, PRISMA, multi-database search |
| `hypothesis` | Competing hypotheses, experimental design |
| `citations` | BibTeX, DOI lookup, bibliography management |
| `peer-review` | Manuscript evaluation, rebuttal responses |
| `grants` | NSF, NIH, DOE, DARPA proposals |
| `statistics` | Test selection, power analysis, APA reporting |
| `qualitative-research` | Thematic analysis, grounded theory, interviews |
| `open-science` | Preregistration, OSF, FAIR data, reproducibility |
| `research-ethics` | IRB, informed consent, CBPR, CRediT |
| `data-management` | FAIR DMPs, metadata standards, versioning |
| `advanced-statistics` | Causal inference, DAGs, multilevel models, SEM |
| `research-communication` | Policy briefs, press releases, video abstracts |
