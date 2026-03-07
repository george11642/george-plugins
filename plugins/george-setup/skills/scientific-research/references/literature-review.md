# Literature Review Reference

## Overview

Conduct systematic, comprehensive literature reviews following rigorous academic methodology. Search multiple databases, synthesize findings thematically, verify citations, and generate professional documents.

## Core Workflow

### Phase 1: Planning and Scoping
- Define research question using PICO framework (Population, Intervention, Comparison, Outcome)
- Determine review type (narrative, systematic, scoping, meta-analysis)
- Set boundaries (time period, geography, study types)
- Develop search strategy with Boolean operators (AND, OR, NOT)
- Set inclusion/exclusion criteria

### Phase 2: Systematic Search
**Databases** (use minimum 3):
- **PubMed**: `gget search pubmed "terms"` -- biomedical literature
- **bioRxiv/medRxiv**: `gget search biorxiv "terms"` -- preprints
- **arXiv**: Physics, math, CS, q-bio preprints
- **Semantic Scholar**: 200M+ papers, cross-disciplinary
- **Google Scholar**: Comprehensive coverage

**Document all searches**: queries, dates, result counts for reproducibility.

### Phase 3: Screening and Selection
1. Deduplicate by DOI (primary) or title (fallback)
2. Title screening against criteria
3. Abstract screening with documented exclusions
4. Full-text screening with specific reasons
5. Create PRISMA flow diagram

### Phase 4: Data Extraction and Quality
- Extract: metadata, design, sample size, findings, limitations, funding
- Assess quality: Cochrane Risk of Bias (RCTs), Newcastle-Ottawa (observational), AMSTAR 2 (reviews)
- Organize by 3-5 major themes

### Phase 5: Synthesis
- Write thematically, NOT study-by-study summaries
- Synthesize across studies within each theme
- Compare/contrast approaches and results
- Identify consensus and controversy
- Evaluate evidence quality and consistency

### Phase 6: Citation Verification
```bash
python scripts/verify_citations.py my_review.md
```
- Verify all DOIs resolve correctly
- Check metadata matches against CrossRef
- Correct errors and re-verify

### Phase 7: Document Generation
```bash
python scripts/generate_pdf.py my_review.md --citation-style apa --output review.pdf
```

## Prioritizing High-Impact Papers

| Paper Age | Citations | Classification |
|-----------|-----------|----------------|
| 0-3 years | 20+ | Noteworthy |
| 0-3 years | 100+ | Highly Influential |
| 3-7 years | 500+ | Landmark Paper |
| 7+ years | 1000+ | Foundational |

**Venue Tiers**: Tier 1 (Nature, Science, Cell, NEJM, Lancet) > Tier 2 (IF>10, top conferences) > Tier 3 (IF 5-10) > Tier 4 (lower-impact)

## Citation Chaining
- **Forward**: Find papers citing key papers (Semantic Scholar, Google Scholar "Cited by")
- **Backward**: Review references from included papers

## Common Pitfalls
1. Single database search
2. No search documentation
3. Study-by-study summaries instead of thematic synthesis
4. Unverified citations
5. Too broad or too narrow search
6. Ignoring preprints
7. No quality assessment
8. Publication bias
