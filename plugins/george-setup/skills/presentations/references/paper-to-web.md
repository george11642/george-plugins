# Paper-to-Web Reference (Paper2All Pipeline)

## Overview

Transforms academic papers (LaTeX or PDF) into three formats:
1. **Paper2Web**: Interactive, explorable academic homepages
2. **Paper2Video**: Professional presentation videos with narration
3. **Paper2Poster**: Print-ready conference posters

Uses LLM-powered content extraction, design generation, and iterative refinement.

## When to Use

- Converting papers to websites for promotion
- Generating conference posters from paper content
- Creating video abstracts or presentation videos
- Preparing materials for social media or lab websites
- Batch processing multiple papers

**Trigger phrases**: "Convert paper to website", "paper2web", "video abstract", "paper2poster", "interactive homepage for paper", "transform paper into promotional materials".

## Prerequisites

### Installation
```bash
git clone https://github.com/YuhangChen1/Paper2All.git
cd Paper2All
conda create -n paper2all python=3.11
conda activate paper2all
pip install -r requirements.txt
```

### API Keys (.env)
```
OPENAI_API_KEY=your_key
# Optional: GOOGLE_API_KEY, GOOGLE_CSE_ID (for logo search)
```

### System Dependencies
- LibreOffice (document conversion)
- Poppler utilities (PDF processing)
- NVIDIA GPU 48GB (optional, for talking-head videos)

## Quick Start

```bash
# All components (website + poster + video)
python pipeline_all.py --input-dir "path/to/paper" --output-dir "path/to/output" --model-choice 1

# Website only
python pipeline_all.py ... --generate-website

# Poster with custom size
python pipeline_all.py ... --generate-poster --poster-width-inches 60 --poster-height-inches 40

# Video (lightweight pipeline)
python pipeline_light.py --model_name_t gpt-4.1 --model_name_v gpt-4.1 --result_dir "output" --paper_latex_root "paper"
```

## Input Requirements

### LaTeX Source (Recommended)
```
paper_directory/
  main.tex
  sections/          # optional
  figures/
  tables/
  bibliography.bib
```

### PDF
- High-quality with embedded fonts
- Selectable text (not scanned)
- 300+ DPI figures preferred

### Batch Processing
```
input/
  paper1/main.tex
  paper2/main.tex
  paper3/main.tex
```

## Paper2Web: Interactive Websites

**Key Features**: Responsive multi-section layouts, interactive figures/tables/citations, mobile-friendly, automatic logo discovery, aesthetic refinement.

**Best For**: Post-publication promotion, preprint enhancement, lab websites.

**Output**: `output/paper_name/website/index.html`

## Paper2Video: Presentation Videos

**Key Features**: Automated slide generation, natural speech synthesis, synchronized cursor movements, optional talking-head (requires GPU), multi-language.

**Best For**: Video abstracts, conference presentations, course materials, YouTube.

**Output**: `output/paper_name/video/final_video.mp4`

## Paper2Poster: Conference Posters

**Key Features**: Custom dimensions, professional templates, institution branding, QR codes, 300+ DPI output.

**Best For**: Conference poster sessions, symposiums, virtual conferences.

**Output**: `output/paper_name/poster/poster_final.pdf`

## Parameters

### Model Selection
- `--model-choice 1`: GPT-4 (best balance)
- `--model-choice 2`: GPT-4.1 (latest, higher cost)
- `--model_name_t gpt-3.5-turbo`: Faster, lower cost

### Component Selection
- `--generate-website`
- `--generate-poster`
- `--generate-video`
- `--enable-talking-head` (requires GPU)

### Customization
- `--poster-width-inches`, `--poster-height-inches`
- `--video-duration`
- `--enable-logo-search`

## Decision Tree

```
Need promotional materials?
|
+- Permanent online presence? -> Paper2Web
+- Physical conference materials?
|  +- Poster session? -> Paper2Poster
|  +- Oral presentation? -> Paper2Video
+- Video content?
|  +- Journal video abstract? -> Paper2Video (5-10 min)
|  +- Conference talk? -> Paper2Video (15-20 min)
|  +- Social media? -> Paper2Video (1-3 min)
+- Complete package? -> All three
```

## Component Priority (Tight Deadlines)

1. **Website** (fastest, ~15-30 min)
2. **Poster** (moderate, ~10-20 min)
3. **Video** (slowest, ~20-60 min; 60-120 with talking-head)

## Resource Requirements

| Component | Time | API Cost (GPT-4) |
|-----------|------|-------------------|
| Website | 15-30 min | $0.50-2.00 |
| Poster | 10-20 min | $0.30-1.00 |
| Video (no head) | 20-60 min | $1.00-3.00 |
| Video (w/ head) | 60-120 min | $1.00-3.00 |
| Complete package | 45-120 min | $2.00-6.00 |

**Hardware**: 16GB RAM min (32GB recommended), multi-core CPU, NVIDIA A6000 48GB for talking-head.

## Output Structure

```
output/paper_name/
  website/
    index.html, styles.css, assets/
  poster/
    poster_final.pdf, poster_final.png, poster_source/
  video/
    final_video.mp4, slides/, audio/, subtitles/
```

## Deployment

**Website**: GitHub Pages, university servers, Netlify/Vercel
**Poster**: Professional printing services, university print shops
**Video**: YouTube, institutional repositories, conference platforms, social media

## Quality Assurance

**Website**: Test on multiple devices, verify links, check figure quality.
**Poster**: Print test page, verify readability from 3-6 feet, check colors.
**Video**: Watch entire video, verify audio sync, test on different devices.

## Visual Enhancement

Add scientific schematics to enhance any output:
```bash
python scripts/generate_schematic.py "your diagram description" -o figures/output.png
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| LaTeX parsing errors | Ensure source compiles: `pdflatex main.tex` |
| Poor figure quality | Use vector formats (PDF, SVG), 300+ DPI rasters |
| Video generation fails | Check disk space (5GB+), verify dependencies |
| Poster layout issues | Check dimensions (24-72" range), curate long content |
| API errors | Verify keys in `.env`, check credit balance |

## Platform-Specific Features

**Twitter/X** (English): Use numeric folder names.
**Xiaohongshu** (Chinese): Use alphanumeric folder names.
**Conference formatting**: Specify poster sizes, video length limits, branding requirements.
