---
name: data-viz
description: "Master data visualization skill. Use when: creating charts, plots, graphs, dashboards, infographics, generative art, algorithmic art, data storytelling, scientific figures, statistical plots, flow fields, particle systems, animations, 3D visualizations, heatmaps, treemaps, sankey diagrams, choropleth maps, candlestick charts, publication figures, poster figures, exploratory data analysis, visual analytics, Excel charts, pivot tables, conditional formatting, color themes, palette selection, animated GIF, PIL animation, Slack GIF, geographic maps, Folium, network graphs, NetworkX, Sankey, force-directed, real-time dashboards, live updates, Dash streaming, WCAG accessibility, color blind, D3 custom visualization, statistical plots, forest plots, survival analysis. Triggers: visualize, plot, chart, graph, dashboard, infographic, generative, algorithmic art, p5.js, matplotlib, plotly, seaborn, D3, bokeh, diagram, figure, heatmap, histogram, scatter, bar chart, pie chart, box plot, violin plot, contour, surface, animate, render data, data story, excel chart, pivot table, conditional formatting, color theme, palette selection, animated gif, bounce, pulse, shake, easing, PIL animation, algorithmic philosophy, generative manifesto, choropleth, Folium, geographic map, Sankey, NetworkX, network graph, Dash, real-time, live dashboard, streaming chart, WCAG, color blind, accessible chart, D3, force-directed, statistical plots, accessibility, pairplot, clustermap, forest plot, Kaplan-Meier, Bland-Altman, QQ plot, error bars. File types: .py, .html, .js, .ipynb, .png, .svg, .pdf, .xlsx, .gif."
---

# Data Visualization

Consolidated skill covering static plots, interactive charts, dashboards, infographics, and generative art. Routes to specialized references by task type.

## Task Router

| Need | Tool | Reference |
|------|------|-----------|
| Static plots, publication figures, subplots, styling | Matplotlib | `references/matplotlib.md` |
| Statistical plots (distributions, regressions, pair plots) | Seaborn + Matplotlib | `references/matplotlib.md` |
| Deep statistical: pairplot, clustermap, QQ, forest, survival | Seaborn + Matplotlib + lifelines | `references/statistical-plots.md` |
| Interactive charts, web-ready, hover/zoom/pan | Plotly Express / Graph Objects | `references/plotly.md` |
| Dashboards with callbacks, multi-page apps | Plotly Dash | `references/plotly.md` |
| Real-time / live dashboards, dcc.Interval, streaming | Plotly Dash | `references/realtime-dashboards.md` |
| Geographic maps, choropleth, scatter_map, Folium, GIS | Plotly / Folium | `references/geographic-maps.md` |
| Network graphs, Sankey, force-directed, NetworkX, treemap | Plotly + NetworkX | `references/network-graphs.md` |
| WCAG accessibility, color blindness, alt text, ARIA | Best practices | `references/accessibility-compliance.md` |
| Custom web viz, D3 force layout, React + D3 | D3.js | `references/d3-custom-viz.md` |
| AI-generated infographics, visual data storytelling | Gemini MCP | `references/infographics.md` |
| Generative art, algorithmic art, flow fields, p5.js | p5.js | `references/generative-art.md` |
| Large-dataset server-side rendering | Bokeh / Datashader | Use Context7 for API docs |
| Excel charts, pivot tables, conditional formatting, data validation | openpyxl + pandas | `references/excel-charts.md` |
| Color themes, palette selection, professional styling | Theme factory | `references/color-themes.md` |
| Animated GIFs, PIL animation, Slack GIFs, easing functions | Pillow / matplotlib.animation | `references/animated-visualizations.md` |

## Decision Tree

```
What is the output?
  ART (generative, algorithmic, creative) --> p5.js (references/generative-art.md)
  INFOGRAPHIC (visual storytelling, poster-style) --> Gemini MCP (references/infographics.md)
  ANIMATED GIF / Slack GIF --> PIL + easing (references/animated-visualizations.md)
  EXCEL FILE (charts, pivot tables, dashboards) --> openpyxl (references/excel-charts.md)
  COLOR THEME / PALETTE --> references/color-themes.md
  DATA CHART/PLOT -->
    Need interactivity (hover, zoom, pan, callbacks)?
      YES --> Need full dashboard with state/callbacks?
        YES --> Plotly Dash
        NO  --> Plotly Express (px for quick, go for custom)
      NO  --> Need statistical semantics (distributions, regression, facets)?
        YES --> Seaborn (builds on matplotlib)
        NO  --> Matplotlib OO API
    Need 3D?
      Static 3D --> mpl_toolkits.mplot3d or Plotly go.Surface
      Interactive 3D --> Plotly scatter_3d / surface
    Need animation?
      Scientific/data --> matplotlib.animation (FuncAnimation, save to mp4/gif)
      Creative/Slack GIF --> PIL frame-by-frame (references/animated-visualizations.md)
      Web --> Plotly animation_frame or D3 transitions
    Need maps?
      Choropleth / scatter / GIS → references/geographic-maps.md
      Folium (layers, popups, clusters) → references/geographic-maps.md
    Need network/hierarchy?
      Sankey (flows) → references/network-graphs.md
      Treemap / Sunburst → references/network-graphs.md
      NetworkX force-directed → references/network-graphs.md
    Need live/streaming data?
      dcc.Interval polling → references/realtime-dashboards.md
      extendData streaming → references/realtime-dashboards.md
    Need statistical depth?
      pairplot, clustermap, lmplot → references/statistical-plots.md
      QQ plot, forest plot, survival → references/statistical-plots.md
    Need custom web viz?
      D3 force layout, React + D3 → references/d3-custom-viz.md
    Accessibility required?
      WCAG checklist, color blindness → references/accessibility-compliance.md
```

## Matplotlib Essentials

Always use OO interface: `fig, ax = plt.subplots(figsize=(10, 6), constrained_layout=True)`.

| Type | Method | When |
|------|--------|------|
| Line | `ax.plot()` | Time series, trends |
| Scatter | `ax.scatter()` | Correlations |
| Bar | `ax.bar()` / `ax.barh()` | Categorical comparisons |
| Histogram | `ax.hist()` | Distributions |
| Heatmap | `ax.imshow()` + `colorbar` | Matrices, correlations |
| Box/Violin | `ax.boxplot()` / `ax.violinplot()` | Statistical spread |
| Contour | `ax.contour()` | 2D scalar fields |

Colormaps: `viridis` (default, accessible), `cividis` (colorblind-safe), `coolwarm` (diverging). Avoid `jet`.

Seaborn integration: `import seaborn as sns; sns.set_theme()` then use `sns.histplot()`, `sns.pairplot()`, `sns.heatmap()` for statistical plots with automatic aesthetics.

Save: `plt.savefig('fig.png', dpi=300, bbox_inches='tight')`. Close: `plt.close(fig)`.

See `references/matplotlib.md` for layouts, 3D, animations, styling, and export details.

## Plotly Essentials

Two APIs: `px` (high-level, DataFrames) and `go` (low-level, fine control). Combine: start with `px`, refine with `fig.update_layout()`.

Key chart types: scatter, line, bar, histogram, box, violin, heatmap, sunburst, treemap, sankey, candlestick, choropleth, scatter_3d, surface.

Templates: `plotly_white`, `plotly_dark`, `ggplot2`, `seaborn`, `simple_white`.

Export: `fig.write_html('chart.html')` (interactive), `fig.write_image('chart.png')` (static, needs kaleido).

Dash: `dcc.Graph(figure=fig)` inside `app.layout`. Use `@app.callback` for interactivity.

See `references/plotly.md` for all chart types, subplots, interactivity, and Dash patterns.

## Infographics Essentials

Use Gemini MCP for AI-generated infographics. Workflow: `gemini_image` generates, `gemini_analyze` scores, `gemini_image_edit` refines. Loop until quality threshold met.

Types: statistical, timeline, process, comparison, list, geographic, hierarchical.
Styles: corporate, healthcare, technology, education, marketing, finance.
Palettes: `wong` (recommended), `ibm`, `tol`.

See `references/infographics.md` for CLI usage, quality thresholds, prompt tips, and research integration.

## Generative Art Essentials

p5.js for algorithmic/generative art. Always use seeded randomness (`randomSeed(seed); noiseSeed(seed)`) for reproducibility.

Core techniques: flow fields (Perlin noise vectors), particle systems, recursive structures, circle packing, Voronoi tessellation, L-systems.

Output: self-contained HTML artifact with inline p5.js. Include sidebar with seed navigation (prev/next/random) and parameter sliders.

See `references/generative-art.md` for philosophy framework, implementation patterns, templates, and parameter design.

## Accessibility

Apply these rules to every visualization, not just when asked:

- **Color**: Use colorblind-safe palettes (viridis/cividis for matplotlib, wong for infographics). Never encode meaning with color alone.
- **Redundancy**: Add patterns, hatching, or markers alongside color. Use distinct line styles (solid, dashed, dotted).
- **Contrast**: Minimum 4.5:1 for text, 3:1 for graphical elements (WCAG AA). Test with grayscale conversion.
- **Alt text**: Every chart saved as an image needs a descriptive alt text string. Format: "[Chart type] showing [relationship] of [variables]. Key finding: [insight]."
- **Labels**: Direct-label lines/bars when possible instead of relying on legends. Use `fontsize>=12` for readability.
- **Screen readers**: For web charts, add `role="img"` and `aria-label` to container divs. Plotly has built-in `fig.update_layout(meta=...)`.

## Performance

- **Large datasets (>100k points)**: Use `rasterized=True` in matplotlib, `scattergl` trace type in Plotly, or Datashader for server-side aggregation.
- **Web optimization**: `fig.write_html('chart.html', include_plotlyjs='cdn')` cuts file size by ~3MB. Compress PNGs with `pngquant`.
- **Memory**: Always `plt.close(fig)` after saving. In loops, use `plt.close('all')`.
- **Animation**: Prefer `FuncAnimation` with `blit=True` for matplotlib. For web, Plotly `animation_frame` handles transitions automatically.
- **Notebook rendering**: Use `%matplotlib inline` for static, `%matplotlib widget` for interactive. Plotly: `fig.show(renderer='notebook')`.

## Choosing a Tool (Quick Matrix)

| Criterion | Matplotlib | Seaborn | Plotly | Dash | Infographics | p5.js |
|-----------|-----------|---------|--------|------|-------------|-------|
| Interactivity | Limited | Limited | Full | Full + callbacks | None | Full |
| Publication quality | Excellent | Excellent | Good | Good | Good | N/A |
| Learning curve | Moderate | Low | Low (px) | Moderate | None | Moderate |
| Web deployment | Manual | Manual | Native HTML | Native | Image embed | Native HTML |
| Best for | Papers, reports | Statistical EDA | Dashboards, exploration | Apps | Storytelling | Art |
