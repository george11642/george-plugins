# Open Science: Preregistration, Reproducibility, and Open Data

## Why Open Science Matters

The replication crisis (2011–present) revealed widespread problems: inflated effect sizes, undisclosed flexibility in analysis, publication bias toward positive results. Open science practices are the field's systemic response. Key findings:
- Only ~36-50% of psychology studies replicated (Open Science Collaboration, 2015)
- Biomedical research replication rates similarly low
- Open practices increase transparency, trust, and cumulative knowledge

---

## Preregistration

Preregistration is posting a **time-stamped, read-only plan** of your study to a public registry before data collection begins. It separates confirmatory (hypothesis-testing) from exploratory (hypothesis-generating) analyses.

### What to Preregister

A complete preregistration includes:
1. **Research questions and hypotheses**: Written as testable, directional statements
2. **Study design**: Experimental vs observational, between vs within, procedures
3. **Participants/sample**: Eligibility criteria, planned sample size with power analysis
4. **Measures and materials**: All primary and secondary outcome measures
5. **Analysis plan**: Specific statistical tests, model specifications, covariates
6. **Exclusion criteria**: Data quality thresholds, outlier handling, missing data rules
7. **Timeline**: When data collection starts and ends

### AsPredicted Format (9 Questions)

The AsPredicted.org format is the most concise preregistration template:
1. Have any data been collected for this study already?
2. What's the main question being asked or hypothesis being tested?
3. Describe the key dependent variable(s)
4. How many and which conditions will participants be in?
5. Specify exactly which analysis(es) you will conduct
6. Any secondary hypotheses?
7. How many observations will be collected or what determines sample size?
8. Anything else you would like to pre-register?
9. Have you looked at the data (including checking assumptions) before making these decisions?

### OSF Preregistration Workflow

1. Create account at osf.io
2. Create project (public or private)
3. Click "Registrations" → "New Registration"
4. Choose template (OSF Standard, AsPredicted, Clinical Trials, etc.)
5. Complete all fields
6. Submit — you receive a time-stamped, uneditable DOI
7. Add preregistration DOI to your eventual manuscript methods section

**OSF Preregistration templates available (as of 2025)**:
- OSF Preregistration (recommended general-purpose)
- AsPredicted
- Secondary Data Preregistration
- Qualitative Preregistration
- Replication Recipe
- Registered Report Protocol

### Registered Reports

Registered Reports (RRs) represent the gold standard — peer review happens **before data collection**:

**Stage 1 (In Principle Acceptance)**:
1. Submit introduction + methods to a journal offering RR format
2. Reviewers evaluate scientific question and methodology
3. If accepted: receive "in principle acceptance" (IPA) — the journal commits to publish regardless of results

**Stage 2**:
4. Conduct the study following the registered protocol
5. Submit complete manuscript
6. Reviewers verify you followed the protocol
7. Publish (findings cannot be rejected because they are null)

**Benefits**: Eliminates publication bias, file-drawer problem, HARKing (Hypothesizing After Results are Known)

**Journals offering RRs**: ~300+ journals across disciplines (see cos.io/rr for full list). Includes Nature Human Behaviour, PLOS ONE, Cortex, Royal Society Open Science.

### Time-Stamped Preregistration for Gray Areas

When full preregistration is not feasible (e.g., secondary data analysis, naturalistic studies):
- Upload your analysis plan to OSF as a **file with automatic time-stamping** before running analyses
- Clearly state in the manuscript: "This was a secondary data analysis; the analysis plan was posted to OSF prior to analysis [link]"
- This is imperfect but better than no preregistration

---

## Open Data Standards

### FAIR Principles

Published in *Scientific Data* (Wilkinson et al., 2016); now the global standard for research data:

**F — Findable**:
- F1: Data have globally unique, persistent identifiers (DOI, accession number, handle)
- F2: Data are described with rich metadata
- F3: Metadata clearly include the identifier of the data they describe
- F4: Data are registered or indexed in a searchable resource

**A — Accessible**:
- A1: Data are retrievable by their identifier using standardized, open protocols (HTTP, FTP)
- A1.1: Protocol is open, free, and universally implementable
- A1.2: Protocol allows authentication/authorization if necessary
- A2: Metadata are accessible even when data are no longer available

**I — Interoperable**:
- I1: Data use formal, accessible, shared, broadly applicable language for knowledge representation
- I2: Data use vocabularies that follow FAIR principles (ontologies, controlled vocabularies)
- I3: Data include qualified references to other data

**R — Reusable**:
- R1: Data have accurate, relevant attributes (including context, provenance)
- R1.1: Data have clear, accessible data usage license (CC0, CC BY)
- R1.2: Data are associated with detailed provenance
- R1.3: Data meet domain-relevant community standards

### Data Repositories by Discipline

**General purpose**:
- **Zenodo** (CERN): Free, 50GB limit, GitHub integration, DOI minting. Ideal for code + data.
- **Figshare**: Free to 5GB; supports any file type; good for figures and datasets
- **OSF**: Free, integrates with GitHub/Dropbox/Google Drive; good for project-level sharing
- **Dryad**: $120-$170 per submission; specialized for ecology, evolution, biomedical

**Discipline-specific**:
- Psychology/social science: OSF, Harvard Dataverse
- Genomics: NCBI (GenBank, SRA, GEO), European Nucleotide Archive
- Clinical trials: ClinicalTrials.gov (registration AND results required by law in US)
- Neuroimaging: OpenNeuro (fMRI/EEG), OSF
- Environmental: Environmental Data Initiative (EDI), PANGAEA
- Social science: ICPSR, Harvard Dataverse

### Data Availability Statements

Most journals now require a Data Availability Statement. Templates:

**Open data**: "The data that support the findings of this study are openly available in [Repository] at [DOI/URL], reference [citation]."

**Restricted data**: "The data that support the findings of this study are available from [source] but restrictions apply to the availability of these data, which were used under license for the current study. Data are available from the authors upon reasonable request and with permission of [source]."

**No data**: "This study did not generate new data. All data analyzed are from previously published studies cited in the references."

### Anonymization for Human Subjects Data

Before depositing human subjects data publicly:
1. Remove all direct identifiers (name, address, SSN, DOB if specific)
2. Assess quasi-identifier combinations (zip + age + race can re-identify)
3. Consider: data aggregation, generalization, noise addition, k-anonymity, synthetic data
4. Check IRB approval language — public deposit may require re-consent
5. Document anonymization procedures in the README

---

## Reproducibility Checklists by Discipline

### Psychology / Behavioral Sciences

- [ ] Effect sizes reported (Cohen's d, eta-squared, r) with 95% CIs
- [ ] Preregistration link in methods
- [ ] All exclusion criteria stated (pre-registered)
- [ ] All collected measures reported (no selective reporting)
- [ ] Sample size justification (power analysis)
- [ ] Raw data deposited in repository
- [ ] Analysis code deposited (R, Python, SPSS syntax)
- [ ] All materials available (stimuli, survey instruments, codebooks)
- [ ] JARS-Quant or JARS-Qual reporting standards followed

### Biomedical / Clinical

- [ ] CONSORT checklist (RCTs) or STROBE (observational)
- [ ] Trial registration on ClinicalTrials.gov with pre-specified primary outcome
- [ ] ARRIVE 2.0 checklist (if animal research)
- [ ] Protocol paper published before study completion
- [ ] Statistical Analysis Plan (SAP) finalized before unblinding
- [ ] All adverse events reported
- [ ] PROSPERO registration (systematic reviews and meta-analyses)

### Computational / Data Science

- [ ] All code in version-controlled repository (GitHub)
- [ ] README with environment setup instructions
- [ ] Requirements file (requirements.txt, environment.yml, renv.lock)
- [ ] Random seeds set for all stochastic operations
- [ ] Container (Docker/Singularity) for full environment reproducibility
- [ ] Zenodo DOI for code version cited in paper
- [ ] Data provenance documented (where did raw data come from, what transformations applied)

---

## Open Code

### GitHub + Zenodo DOI Workflow

1. Develop code on GitHub with meaningful commits
2. Tag a release version (v1.0.0) when paper is submitted
3. Connect GitHub repo to Zenodo (Settings → Webhooks → Zenodo)
4. Each GitHub release automatically creates a citable Zenodo DOI
5. Add DOI badge to README
6. Cite as: Smith, J. (2025). Analysis code for "Title" (v1.0.0). Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

### CITATION.cff File

Add a `CITATION.cff` file to your GitHub repository root so tools like GitHub, Zenodo, and Zotero can automatically extract citation metadata:

```yaml
cff-version: 1.2.0
message: "If you use this software, please cite it as below."
authors:
  - family-names: Smith
    given-names: Jane
    orcid: https://orcid.org/0000-0000-0000-0000
title: "Analysis code for X study"
version: 1.0.0
date-released: 2025-01-01
url: "https://github.com/username/repo"
```

### README for Reproducibility

Every shared codebase should have a README including:
- Project description and associated paper DOI
- Directory structure
- Installation/environment setup (step-by-step)
- How to reproduce each analysis (script names, order, expected outputs)
- Data availability (where to get the data, or note it's included)
- Software versions used (session info / sessionInfo() / pip list)
- License

---

## Replication and Meta-Science

### Reporting for Replication

Write your methods section as if the reader knows nothing and must replicate your study. Include:
- Exact software versions and hardware (for computational work)
- Participant recruitment script verbatim
- Full stimuli (or link to repository)
- Exact timing parameters
- Randomization algorithm and seed
- Exact analysis code (not pseudocode)

### Registered Replication Reports

Pre-registered, multi-lab replications of important findings. Published in:
- *Advances in Methods and Practices in Psychological Science* (AMPPS)
- *Perspectives on Psychological Science*
- Coordinated through OSF's "Many Labs" projects

### Open Practice Badges (Center for Open Science)

Many journals award badges for open practices:
- **Open Data badge**: Data publicly available with enough documentation to reproduce results
- **Open Materials badge**: Materials publicly available to reproduce procedure
- **Preregistered badge**: Hypothesis and design registered before data collection
- **Preregistered + Analysis Plan badge**: Full analysis plan also registered

---

## Key Resources and Links

- Center for Open Science: https://www.cos.io
- OSF: https://osf.io
- AsPredicted: https://aspredicted.org
- FAIR Principles: https://www.go-fair.org/fair-principles/
- Registered Reports journal list: https://www.cos.io/initiatives/registered-reports
- Zenodo: https://zenodo.org
- ClinicalTrials.gov: https://clinicaltrials.gov
- Open Science Collaboration (2015). Estimating the reproducibility of psychological science. *Science, 349*(6251), aac4716.
- Wilkinson, M.D. et al. (2016). The FAIR Guiding Principles. *Scientific Data, 3*, 160018.
