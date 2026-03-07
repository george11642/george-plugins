# Scientific Visualization Reference

## Overview

Create publication-ready figures with multi-panel layouts, error bars, significance markers, and colorblind-safe palettes using matplotlib, seaborn, and plotly.

## Resolution and File Formats

- **Raster images** (photos, microscopy): 300-600 DPI
- **Line art** (graphs, plots): 600-1200 DPI or vector format
- **Vector formats** (preferred): PDF, EPS, SVG
- **Raster formats**: TIFF, PNG -- NEVER JPEG for scientific data

## Journal Figure Dimensions

| Journal | Single Column | Double Column |
|---------|--------------|---------------|
| Nature | 89 mm | 183 mm |
| Science | 55 mm | 175 mm |
| Cell | 85 mm | 178 mm |

## Color: Colorblind Accessibility

**Always use colorblind-friendly palettes.**

**Okabe-Ito palette** (recommended):
```python
okabe_ito = ['#E69F00', '#56B4E9', '#009E73', '#F0E442',
             '#0072B2', '#D55E00', '#CC79A7', '#000000']
```

- Heatmaps: Use `viridis`, `plasma`, `cividis` (perceptually uniform)
- Diverging data: Use `PuOr`, `RdBu`, `BrBG` -- never `jet` or `rainbow`
- Always test in grayscale
- Add redundant encoding (line styles, markers, patterns)

## Typography

- Sans-serif fonts: Arial, Helvetica, Calibri
- Minimum sizes at final print: axis labels 7-9pt, tick labels 6-8pt, panel labels 8-12pt bold
- Sentence case: "Time (hours)" not "TIME (HOURS)"
- Always include units in parentheses

## Multi-Panel Figures

- Label panels with bold letters (A, B, C -- uppercase for most journals, lowercase for Nature)
- Consistent styling across all panels
- Use `GridSpec` for flexible layouts
- Adequate white space between panels

## Statistical Rigor in Figures

- Error bars: specify SD, SEM, or CI in caption
- Sample size (n) in figure or caption
- Significance markers (*, **, ***)
- Show individual data points when possible (not just summary stats)

## Quick Start: Publication Figure

```python
import matplotlib.pyplot as plt
from style_presets import configure_for_journal
configure_for_journal('nature', figure_width='single')

fig, ax = plt.subplots(figsize=(3.5, 2.5))
ax.plot(x, y, label='Treatment')
ax.set_xlabel('Time (hours)')
ax.set_ylabel('Response (mV)')
ax.legend(frameon=False)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

from figure_export import save_publication_figure
save_publication_figure(fig, 'figure1', formats=['pdf', 'png'], dpi=300)
```

## Seaborn for Statistical Plots

```python
import seaborn as sns
sns.set_theme(style='ticks', context='paper', font_scale=1.1)
sns.set_palette('colorblind')

# Box plot with individual points
fig, ax = plt.subplots(figsize=(3.5, 3))
sns.boxplot(data=df, x='treatment', y='response', palette='Set2', ax=ax)
sns.stripplot(data=df, x='treatment', y='response', color='black', alpha=0.3, size=3, ax=ax)
sns.despine()
```

## Plotly (Interactive)

```python
fig.update_layout(font=dict(family='Arial', size=10), plot_bgcolor='white')
fig.write_image('figure.png', scale=3)  # ~300 DPI
```

## Checklist Before Submission

- [ ] Resolution meets journal requirements (300+ DPI)
- [ ] Correct file format (vector for plots, TIFF for images)
- [ ] Figure size matches journal specs
- [ ] All text readable at final size (6+ pt)
- [ ] Colorblind-friendly colors
- [ ] Works in grayscale
- [ ] All axes labeled with units
- [ ] Error bars with definition in caption
- [ ] Panel labels present and consistent
- [ ] No chart junk or 3D effects

## Common Pitfalls

1. Font too small at final size
2. JPEG for graphs (creates artifacts)
3. Red-green color combinations
4. Low resolution
5. Missing units on axes
6. 3D effects distorting data
7. Inconsistent styling across figures
8. No error bars
9. Truncated axes without justification
