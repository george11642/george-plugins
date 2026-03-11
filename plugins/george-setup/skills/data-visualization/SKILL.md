---
name: data-visualization
description: "Use when creating charts, plots, graphs, dashboards, Excel reports with openpyxl, infographics, generative art, statistical plots, animations, heatmaps, treemaps, sankey diagrams, choropleth maps, geographic maps, network graphs, D3.js custom visualizations, or accessible data visualizations (WCAG, colorblind-safe palettes, alt text for charts). Tools: matplotlib, plotly, seaborn, D3, Dash, p5.js, openpyxl, Pillow, Folium, NetworkX, bokeh."
---

# Data Visualization

Master skill for static plots, interactive charts, dashboards, infographics, and generative art. Routes to specialized references by task type.

## Task Router

| Need | Tool | Reference |
|------|------|-----------|
| Static plots, publication figures, subplots | Matplotlib | [references/matplotlib.md](references/matplotlib.md) |
| Statistical plots (distributions, regressions) | Seaborn + Matplotlib | [references/matplotlib.md](references/matplotlib.md) |
| Deep statistical: pairplot, QQ, forest, survival | Seaborn + lifelines | [references/statistical-plots.md](references/statistical-plots.md) |
| Interactive charts, hover/zoom/pan | Plotly Express / GO | [references/plotly.md](references/plotly.md) |
| Dashboards with callbacks, multi-page apps | Plotly Dash | [references/plotly.md](references/plotly.md) |
| Real-time / live dashboards, streaming | Plotly Dash | [references/realtime-dashboards.md](references/realtime-dashboards.md) |
| Geographic maps, choropleth, GIS | Plotly / Folium | [references/geographic-maps.md](references/geographic-maps.md) |
| Network graphs, Sankey, treemap, sunburst | Plotly + NetworkX | [references/network-graphs.md](references/network-graphs.md) |
| WCAG accessibility, color blindness, alt text | Best practices | [references/accessibility-compliance.md](references/accessibility-compliance.md) |
| Custom web viz, D3 force layout, React + D3 | D3.js | [references/d3-custom-viz.md](references/d3-custom-viz.md) |
| AI-generated infographics, data storytelling | Gemini MCP | [references/infographics.md](references/infographics.md) |
| Generative art, flow fields, particle systems | p5.js | [references/generative-art.md](references/generative-art.md) |
| Excel charts, pivot tables, conditional formatting | openpyxl | [references/excel-charts.md](references/excel-charts.md) |
| Color themes, palette selection, styling | Theme factory | [references/color-themes.md](references/color-themes.md) |
| Animated GIFs, PIL animation, easing | Pillow / matplotlib | [references/animated-visualizations.md](references/animated-visualizations.md) |

## Decision Tree

```
Output type?
  ART (generative, algorithmic) --> p5.js (references/generative-art.md)
  INFOGRAPHIC (visual storytelling) --> Gemini MCP (references/infographics.md)
  ANIMATED GIF --> PIL + easing (references/animated-visualizations.md)
  EXCEL FILE --> openpyxl (references/excel-charts.md)
  COLOR THEME --> references/color-themes.md
  DATA CHART -->
    Interactivity needed?
      YES + dashboard --> Plotly Dash
      YES + standalone --> Plotly Express
      NO + statistical --> Seaborn
      NO + general --> Matplotlib OO API
    3D? --> Plotly (interactive) or mplot3d (static)
    Maps? --> references/geographic-maps.md
    Networks? --> references/network-graphs.md
    Live data? --> references/realtime-dashboards.md
    Accessibility? --> references/accessibility-compliance.md
```

## Quick Reference

**Matplotlib**: Always OO interface: `fig, ax = plt.subplots(figsize=(10,6), constrained_layout=True)`. Save: `plt.savefig('fig.png', dpi=300, bbox_inches='tight')`. Close: `plt.close(fig)`.

**Plotly**: Two APIs — `px` (high-level) and `go` (fine control). Export: `write_html()` (interactive) or `write_image()` (static, needs kaleido).

**Colormaps**: `viridis` (default), `cividis` (colorblind-safe), `coolwarm` (diverging). Avoid `jet`.

**Accessibility**: Colorblind-safe palettes always. Never encode meaning with color alone. Add patterns/markers alongside color. Min contrast 4.5:1 text, 3:1 graphical. Alt text for every saved image.

**Performance**: >100k points → `rasterized=True` (mpl) or `scattergl` (Plotly). Always `plt.close(fig)` after saving.

## Layer 3 Skills

| Skill | Use when |
|-------|----------|
| `matplotlib` | Static plots, publication figures, animations |
| `plotly` | Interactive charts, Dash dashboards |
| `statistical-plots` | Pairplot, QQ, forest plot, survival analysis |
| `generative-art` | p5.js algorithmic art, flow fields |
| `infographics` | AI-generated visual data storytelling |
| `geographic-maps` | Choropleth, scatter maps, Folium, GIS |
| `network-graphs` | Sankey, treemap, force-directed, NetworkX |
| `realtime-dashboards` | Live/streaming data, dcc.Interval |
| `d3-custom-viz` | Custom D3.js, React + D3 |
| `excel-charts` | openpyxl charts, pivot tables |
| `color-themes` | Palette selection, professional styling |
| `animated-visualizations` | GIFs, PIL animation, easing functions |
| `accessibility-compliance` | WCAG, color blindness, ARIA |
