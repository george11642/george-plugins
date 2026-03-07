# Research Data Management: FAIR Principles, DMPs, and Best Practices

## Overview

Research data management (RDM) encompasses the practices and infrastructure that ensure research data are organized, documented, preserved, and shared in ways that maximize their long-term value. Good RDM is increasingly required by funders, journals, and institutions.

---

## FAIR Principles: Deep Implementation

FAIR (Wilkinson et al., 2016) is the international standard for research data. It does not prescribe specific tools — it provides guiding principles implemented differently across disciplines.

### F — Findable

Data must be discoverable by both humans and machines.

**F1: (Meta)data are assigned globally unique and persistent identifiers**
- **DOI (Digital Object Identifier)**: Standard for published datasets. Assigned by repositories (Zenodo, Dryad, Figshare)
- **ORCID**: Unique researcher identifier. Register at orcid.org; connect to all your publications and data deposits
- **Accession numbers**: Discipline-specific (GenBank accession, GEO series ID, ClinicalTrials.gov NCT number)
- Avoid URLs as identifiers — they break. DOIs and accession numbers persist even if location changes

**F2: Data are described with rich metadata**
- Metadata should be comprehensive enough that a user can determine relevance without downloading the data
- Include: title, creator(s), date, description, keywords, methods summary, geographic scope, temporal coverage, variable list
- Use controlled vocabularies for keywords when available (MeSH, LCSH)

**F3: Metadata clearly include the identifier of the data they describe**
- The metadata record must explicitly link to the data DOI or accession number
- Cross-reference between related datasets (e.g., raw data → processed data → analysis code)

**F4: (Meta)data are registered or indexed in a searchable resource**
- Deposit in indexed repositories (Zenodo, Dryad, OSF — all indexed by DataCite, Google Dataset Search)
- Register with discipline-specific registries
- Add dataset citation to your manuscript so search engines can index the connection

### A — Accessible

Data should be retrievable once found. Accessible does not mean open — it means access conditions are clear and machine-readable.

**A1: (Meta)data are retrievable by their identifier using a standardized communications protocol**
- HTTPS is the standard open protocol — all major repositories use it
- FTP acceptable; proprietary protocols (institutional drives, email requests only) are not FAIR

**A1.1: The protocol is open, free, and universally implementable**
- No proprietary software required to access the data
- Avoid formats requiring paid software (e.g., SPSS .sav files without PSPP alternative)

**A1.2: The protocol allows for authentication and authorization where necessary**
- Sensitive data can be FAIR and restricted: controlled access via application (dbGaP, UK Biobank model)
- Access conditions must be clearly stated in metadata

**A2: Metadata are accessible even when the data are no longer available**
- The repository metadata record persists even if the dataset is deleted or embargoed
- This is why depositing in established repositories matters — they guarantee metadata persistence

### I — Interoperable

Data should work with other data and systems.

**I1: (Meta)data use a formal, accessible, shared, broadly applicable language**
- Use standard ontologies and controlled vocabularies rather than free text
- **OBO (Open Biological Ontologies)**: GO (Gene Ontology), HPO (Human Phenotype Ontology), UBERON (anatomy)
- **Dublin Core**: General-purpose metadata standard (15 core elements)
- **Darwin Core**: Biodiversity/ecological data
- **SNOMED CT, ICD-10**: Clinical terminology

**I2: (Meta)data use vocabularies that themselves follow FAIR principles**
- Reference vocabularies by URI (e.g., http://purl.obolibrary.org/obo/GO_0005488), not just text labels

**I3: (Meta)data include qualified references to other data**
- Explicitly state relationships: "derived from [DOI]", "uses instrument validated in [DOI]"
- Use DataCite relation types: IsSupplementTo, IsDerivedFrom, IsDocumentedBy, IsPartOf

### R — Reusable

Data should be rich enough in context that others can reuse them.

**R1: (Meta)data have a plurality of accurate and relevant attributes**
- Detailed README / codebook describing every variable
- Collection methods, instruments, and conditions
- Quality control procedures applied
- Known limitations and missing data patterns

**R1.1: (Meta)data are released with a clear and accessible data usage license**
- **CC0** (Public Domain Dedication): Maximum reuse. Recommended for most research data. Waives all rights.
- **CC BY** (Attribution): Reuse allowed with credit. Most common for publications; appropriate for data.
- **CC BY-SA**: Attribution + share-alike (derivative works must use same license). Limits reuse.
- **CC BY-NC**: Non-commercial only. Restricts reuse significantly; avoid unless legally required.
- Custom licenses (e.g., data use agreements for genomic data): acceptable when CC licenses inadequate

**R1.2: (Meta)data are associated with detailed provenance**
- Where did the data come from? (source, collection site, instrument)
- What transformations were applied? (cleaning steps, derived variables)
- Version history: when was each version created, what changed?
- Software and versions used to process data

**R1.3: (Meta)data meet domain-relevant community standards**
- Follow reporting guidelines for your discipline (see: reporting-guidelines.md)
- Use field-specific formats: FITS for astronomy, NetCDF for geospatial, BIDS for neuroimaging

---

## Data Management Plans (DMPs)

A DMP is a living document describing how you will collect, manage, store, share, and preserve your research data.

### NSF DMP Requirements

NSF requires a 2-page Data Management Plan for most proposals. Address:
1. **Data types and formats**: What kinds of data will you produce? What formats?
2. **Standards**: What metadata standards will you use?
3. **Access and sharing**: Will data be publicly shared? Where? When?
4. **Reuse and redistribution**: Any restrictions? Licensing?
5. **Archiving and preservation**: Where will data be preserved long-term? For how long?

NSF program officers expect specificity. Name the repository, the timeline, and the metadata standard.

### NIH Data Sharing Policy

As of January 2023, NIH requires a Data Management and Sharing (DMS) Plan for all research generating scientific data (not just grants ≥$500k as previously).

**NIH DMS Plan elements (6 required sections)**:
1. Data type (nature, volume, format of data)
2. Related tools, software, and/or code
3. Standards (metadata, common data elements)
4. Data preservation, access, and timesharing timelines (must share no later than publication or end of award)
5. Access, distribution, or reuse considerations (privacy, consent, commercial restrictions)
6. Oversight (who is responsible for DMP implementation)

**NIH-designated repositories** (preferred for NIH-funded data):
- NCBI databases (GEO, dbGaP, SRA) for genomic/biological data
- ClinicalTrials.gov for clinical trial data
- NIMH Data Archive for neuroscience/behavioral data
- NHLBI BioData Catalyst
- For general data: Zenodo, Dryad, Figshare acceptable with justification

### DMP Tools

- **DMPTool** (dmptools.org): US-focused; templates for all major funders (NSF, NIH, NEH, DOE); free
- **RDMO** (rdmorganiser.github.io): European/international; more complex, institution-deployable
- **DMP Online** (dmponline.dcc.ac.uk): UK-focused; UKRI templates; free
- **Argos** (argos.openaire.eu): Funder-neutral; machine-readable DMP output

### What a Strong DMP Includes

Beyond funder minimum requirements, strong DMPs include:
- File naming convention specification
- Folder structure plan
- Version control approach
- Backup strategy (3-2-1 rule: 3 copies, 2 media types, 1 offsite)
- Who has access to data during the project
- How access will be managed when personnel change
- Estimated costs for storage and curation (include in budget)

---

## Metadata Standards by Discipline

| Standard | Domain | Key Elements |
|---|---|---|
| **Dublin Core** | General purpose | 15 elements: title, creator, subject, description, date, format, identifier, etc. |
| **DataCite Metadata Schema** | Research datasets | Optimized for DOI minting; mandatory: identifier, creator, title, publisher, year, type |
| **MIAME** | Microarray gene expression | Experimental design, array design, samples, hybridizations, images, data processing |
| **MINSEQE** | Next-gen sequencing | Extends MIAME for sequencing; required by GEO/ArrayExpress |
| **EML (Ecological Metadata Language)** | Ecological data | Dataset, project, geographic, temporal, taxonomic coverage |
| **CF Conventions** | Climate/geophysical | NetCDF data; coordinate variables, standard names, units |
| **BIDS** | Neuroimaging | MRI, fMRI, EEG, MEG data organization and metadata JSON sidecars |
| **Darwin Core** | Biodiversity | Taxon, occurrence, event, location, organism |
| **ABCD** | Natural history collections | Specimens, observations, multimedia |
| **DDI (Data Documentation Initiative)** | Social science surveys | Variables, concepts, questions, response categories |

---

## Data Versioning

### Version Naming Conventions

Use semantic versioning adapted for research data:
- **v1.0**: First publicly released version
- **v1.1**: Minor correction (e.g., fixed typo in variable label, corrected one erroneous value)
- **v1.1-corrections**: Append descriptor for clarity
- **v2.0**: Major revision (e.g., added new variables, reprocessed with different pipeline)

Always publish a **changelog** documenting what changed between versions. Never silently update data without versioning.

### Git LFS for Large Files

Regular Git is not suited for large data files (images, audio, video, large CSVs). Git Large File Storage (Git LFS) stores large files on a remote server while keeping lightweight pointers in the repository:
```bash
git lfs install
git lfs track "*.csv"
git lfs track "*.h5"
git add .gitattributes
git add data/large_dataset.csv
git commit -m "Add large dataset via LFS"
```
GitHub supports Git LFS with 1GB free storage.

### DVC (Data Version Control)

DVC (dvc.org) is purpose-built for data science workflows:
- Tracks data files and ML models like Git tracks code
- Data can be stored in S3, GCS, Azure Blob, SSH, or local remote
- Integrates with Git (stages are stored in .dvc files committed to Git)
- Enables pipeline reproducibility (dvc repro)
- Useful for large datasets, model checkpoints, or data that changes frequently

```bash
dvc init
dvc add data/raw_data.csv           # tracks data file
dvc remote add -d myremote s3://mybucket/dvc-storage
dvc push                             # push data to remote
```

### Changelog Documentation

Maintain a CHANGELOG.md in your data repository:
```markdown
# Changelog

## v2.0 (2025-06-01)
### Changed
- Reprocessed all audio files using updated noise reduction algorithm
- Removed 3 participants who failed attention checks (see exclusion_criteria.md)

## v1.1 (2025-03-15)
### Fixed
- Corrected subject ID 042 data entry error in column "response_time_ms"

## v1.0 (2025-01-10)
- Initial public release
```

---

## Repository Selection Decision Tree

```
Is your data from a specific discipline?
├── Yes → Does your discipline have a mandated or dominant repository?
│   ├── Yes → Use it (GenBank for genomics, ClinicalTrials.gov for trials, GEO for expression)
│   └── No → Use a discipline-specific general repository (Dryad for ecology/evolution; ICPSR for social science)
└── No → Use a general-purpose repository
    ├── Need GitHub integration and DOI? → Zenodo
    ├── Need rich metadata and discoverability? → Figshare
    ├── Want full project-level sharing (data + code + docs)? → OSF
    └── Ecology/evolution emphasis? → Dryad
```

### Embargo Periods

Many journals allow data to be embargoed (not publicly available) until publication:
- Typical embargo: until date of publication or up to 1 year after project end
- NSF requires sharing "as soon as practicable" — typically within 2 years of data collection
- NIH DMS Policy: data must be shared no later than time of first publication of results
- Set embargo when uploading to Zenodo/OSF; the DOI still exists and can be cited in the manuscript

### License Selection Summary

| Scenario | Recommended License |
|---|---|
| Pure factual data (measurements, observations) | CC0 — data are not copyrightable in most jurisdictions; CC0 clarifies legal status |
| Data with creative elements or substantial compilation | CC BY — requires attribution |
| Genomic/health data with restrictions | Custom Data Use Agreement (e.g., dbGaP model) |
| Code accompanying data | MIT or Apache 2.0 (open source); keep separate from data license |

---

## File Organization Best Practices

### Directory Structure (Standard Template)

```
project_name/
├── README.md                    # Project overview, how to reproduce
├── LICENSE                      # Data license (e.g., CC0)
├── CHANGELOG.md                 # Version history
├── data/
│   ├── raw/                     # Original, unmodified data (read-only)
│   ├── processed/               # Cleaned/transformed data
│   └── external/                # Data from external sources
├── code/
│   ├── 01_cleaning.R            # Numbered scripts in execution order
│   ├── 02_analysis.R
│   └── 03_figures.R
├── docs/
│   ├── codebook.md              # Variable definitions
│   ├── data_dictionary.xlsx     # Machine-readable variable metadata
│   └── protocol.md              # Data collection protocol
└── outputs/
    ├── figures/
    └── tables/
```

### File Naming Conventions

- Use ISO 8601 dates: YYYY-MM-DD
- No spaces (use underscores or hyphens): `interview_2025-03-01_p012.wav`
- Version numbers in filename if not using Git: `analysis_v1.2.R`
- Lead with the most general identifier: `study_wave_condition_subject_measure.ext`
- Avoid: special characters (`!@#$%`), overly long names, OS-reserved words (CON, PRN on Windows)

---

## Key References

- Wilkinson, M.D. et al. (2016). The FAIR Guiding Principles for scientific data management. *Scientific Data, 3*, 160018. https://doi.org/10.1038/sdata.2016.18
- FAIR Principles: https://www.go-fair.org/fair-principles/
- NIH DMS Policy: https://sharing.nih.gov/data-management-and-sharing-policy
- DMPTool: https://dmptool.org
- DVC Documentation: https://dvc.org/doc
- DataCite Metadata Schema: https://schema.datacite.org/
- BIDS Specification: https://bids-specification.readthedocs.io/
- The Turing Way: https://the-turing-way.netlify.app/reproducible-research/rdm
