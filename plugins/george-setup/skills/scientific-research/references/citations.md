# Citation Management Reference

## Overview

Search academic databases (Google Scholar, PubMed), extract metadata from DOI/PMID/arXiv, validate BibTeX entries, format and deduplicate bibliographies.

## Workflow

### Phase 1: Paper Discovery

**Google Scholar**:
```bash
python scripts/search_google_scholar.py "topic" --year-start 2020 --limit 100 --output results.json
```
Operators: `"exact phrase"`, `author:name`, `intitle:keyword`, `source:journal`, `-exclude`, `2020..2024`

**PubMed**:
```bash
python scripts/search_pubmed.py '"MeSH Term"[MeSH] AND "keyword"[Title/Abstract]' --date-start 2020 --limit 200 --output results.json
```
Field tags: `[Title]`, `[Author]`, `[MeSH]`, `[Publication Type]`, `[Publication Date]`

### Phase 2: Metadata Extraction

```bash
# From DOI
python scripts/extract_metadata.py --doi 10.1038/s41586-021-03819-2

# From PMID
python scripts/extract_metadata.py --pmid 34265844

# From arXiv
python scripts/extract_metadata.py --arxiv 2103.14030

# Quick DOI to BibTeX
python scripts/doi_to_bibtex.py 10.1038/s41586-021-03819-2

# Batch from file
python scripts/extract_metadata.py --input identifiers.txt --output citations.bib
```

**Metadata Sources**: CrossRef (DOIs), PubMed E-utilities (PMIDs), arXiv API (preprints), DataCite (datasets)

### Phase 3: BibTeX Formatting

```bash
python scripts/format_bibtex.py references.bib --deduplicate --sort year --descending --output clean.bib
```

**Entry Types**: `@article`, `@book`, `@inproceedings`, `@incollection`, `@phdthesis`, `@misc`

**Key Conventions**: `FirstAuthor2024keyword`, protect capitalization with `{}`, use `--` for page ranges, always include DOI.

### Phase 4: Validation

```bash
python scripts/validate_citations.py references.bib --auto-fix --report validation.json --output validated.bib
```

**Checks**: DOI verification, required fields, data consistency, duplicate detection, format compliance.

### Phase 5: Integration

Complete workflow:
1. Search databases -> export JSON
2. Extract metadata -> BibTeX
3. Add specific papers by DOI
4. Format and deduplicate
5. Validate all entries
6. Use in LaTeX: `\bibliography{references}`

## Prioritizing Papers

| Paper Age | Citations | Classification |
|-----------|-----------|----------------|
| 0-3 years | 100+ | Highly Influential |
| 3-7 years | 500+ | Landmark |
| 7+ years | 1000+ | Foundational |

**Venue Tiers**: Tier 1 (Nature, Science, Cell, NEJM) > Tier 2 (IF>10) > Tier 3 (IF 5-10) > Tier 4 (lower)

## Best Practices

- Always use DOIs when available (most reliable identifier)
- Search multiple sources (Scholar + PubMed + arXiv)
- Verify extracted metadata against originals
- Update preprints to published versions
- Validate before every submission
- Never type BibTeX entries manually -- always extract from APIs

## Common Pitfalls

1. Single source bias
2. Accepting metadata blindly
3. Broken/incorrect DOIs
4. Inconsistent formatting
5. Duplicate entries
6. Missing required fields
7. Citing preprints when published version exists
8. Special character issues in LaTeX
