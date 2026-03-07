# Charts & Data Visualization

## Chart Type Selection

| Data Pattern | Best Chart | Alternatives |
|---|---|---|
| Trend over time | Line chart | Area chart, sparkline |
| Comparison (few items) | Bar chart (horizontal) | Grouped bar, lollipop |
| Comparison (many items) | Bar chart (horizontal) | Dot plot, small multiples |
| Part-to-whole | Donut chart | Stacked bar, treemap, waffle |
| Distribution | Histogram | Box plot, violin, density |
| Correlation | Scatter plot | Bubble chart, heatmap |
| Ranking | Horizontal bar | Bump chart, slope chart |
| Flow / Process | Sankey diagram | Funnel chart, flow diagram |
| Geographic | Choropleth map | Dot map, cartogram |
| Hierarchy | Treemap | Sunburst, icicle chart |
| Network | Force-directed graph | Arc diagram, adjacency matrix |
| Real-time | Sparkline, gauge | Live line chart, status grid |
| KPI / Single value | Big number card | Gauge, progress ring |

## Library Recommendations

### JavaScript / Web
| Library | Best For | Complexity |
|---|---|---|
| Chart.js | Simple charts, quick setup | Low |
| Recharts | React dashboards | Low-Medium |
| Nivo | React, beautiful defaults | Medium |
| D3.js | Custom, complex, interactive | High |
| Observable Plot | Quick exploratory charts | Low |
| Apache ECharts | Feature-rich, large datasets | Medium |
| Plotly.js | Scientific, 3D, interactive | Medium |

### Python
| Library | Best For | Complexity |
|---|---|---|
| matplotlib | Publication-quality, full control | Medium |
| seaborn | Statistical visualization | Low |
| plotly | Interactive, web-ready | Low-Medium |
| altair | Declarative, grammar-based | Low |
| bokeh | Interactive dashboards | Medium |

## Dataviz Best Practices

### Color
- Use sequential palettes for ordered data (light to dark)
- Use diverging palettes for data with meaningful midpoint
- Use categorical palettes for nominal data (max 8-10 distinct)
- Ensure colorblind-safe palettes (avoid red-green only)
- Accessible palettes: Viridis, ColorBrewer, Tableau 10

### Labels & Annotations
- Always label axes with units
- Direct labels on data points > legends when possible
- Annotate key data points or anomalies
- Title: state the insight, not just the metric ("Revenue grew 40% in Q3" > "Revenue by Quarter")

### Layout
- Start y-axis at 0 for bar charts (never truncate)
- Line charts can start at non-zero if labeled clearly
- Provide data table alternative for accessibility
- Remove chart junk: unnecessary gridlines, 3D effects, decorative elements

### Responsive Charts
- Use percentage-based container widths
- Reduce label count on mobile (rotate or abbreviate)
- Consider small multiples over complex multi-series charts
- Touch-friendly tooltips (tap, not hover)

## Matplotlib Quick Reference

```python
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['font.family'] = 'sans-serif'
matplotlib.rcParams['font.sans-serif'] = ['Inter', 'Helvetica', 'Arial']

fig, ax = plt.subplots(figsize=(10, 6))
ax.spines[['top', 'right']].set_visible(False)  # Clean axes
ax.set_title('Chart Title', fontsize=16, fontweight='bold', pad=20)
plt.tight_layout()
plt.savefig('chart.png', dpi=150, bbox_inches='tight')
```

## Plotly Quick Reference

```python
import plotly.express as px
import plotly.graph_objects as go

fig = px.bar(df, x='category', y='value', color='group',
             template='plotly_white',
             color_discrete_sequence=px.colors.qualitative.Set2)
fig.update_layout(font_family='Inter', title_font_size=20)
fig.write_html('chart.html')
```
