# UI Chart Types Reference

Complete catalog of 25 chart types with data type matching, color guidance, accessibility notes, and library recommendations. Sourced from ui-ux-pro-max.

## Chart Selection Decision Tree

```
What are you visualizing?
├── Trend over time → Line Chart / Area Chart
├── Comparing categories → Bar Chart (horizontal or vertical)
├── Part-to-whole proportions → Pie/Donut (≤5 items) or Stacked Bar (>5)
├── Correlation/scatter → Scatter Plot / Bubble Chart
├── Heat/density → Heat Map / Choropleth
├── Geographic data → Choropleth Map / Bubble Map
├── Funnel/flow → Funnel Chart / Sankey Diagram
├── Performance vs target → Gauge / Bullet Chart
├── Forecast → Line with Confidence Band
├── Anomaly → Line Chart with Highlights
├── Hierarchy → Treemap / Sunburst
├── Process flow → Sankey / Alluvial Diagram
├── Cumulative changes → Waterfall Chart
├── Multi-variable → Radar/Spider Chart
├── Stock data → Candlestick / OHLC
├── Network/relationships → Network Graph
├── Distribution → Box Plot / Violin Plot
└── Real-time streaming → Streaming Area Chart
```

## Chart Catalog

### 1. Line Chart — Trend Over Time
- **Keywords**: trend, time-series, growth, timeline, progress
- **Secondary**: Area Chart, Smooth Area
- **Colors**: Primary #0080FF, multiple series use distinct colors, fill 20% opacity
- **Perf**: Excellent | **A11y**: Clear line patterns, add pattern overlays for colorblind
- **Libraries**: Chart.js, Recharts, ApexCharts
- **Interactive**: Hover + Zoom

### 2. Bar Chart — Compare Categories
- **Keywords**: compare, categories, ranking
- **Secondary**: Column Chart, Grouped Bar
- **Colors**: Each bar distinct color, sorted descending
- **Perf**: Excellent | **A11y**: Easy to compare, add value labels on bars
- **Libraries**: Chart.js, Recharts, D3.js
- **Interactive**: Hover + Sort

### 3. Pie/Donut — Part-to-Whole
- **Keywords**: percentage, proportion, share
- **Colors**: 5-6 max categories, contrasting palette, large slices first
- **Perf**: Good (limit 6 slices) | **A11y**: Poor — prefer stacked bar with legend
- **Libraries**: Chart.js, Recharts, D3.js

### 4. Scatter/Bubble — Correlation
- **Keywords**: correlation, distribution, relationship, pattern
- **Colors**: Gradient (blue-red) for axis, opacity 0.6-0.8 for density
- **Perf**: Moderate (many points) | **A11y**: Provide data table alternative
- **Libraries**: D3.js, Plotly, Recharts

### 5. Heat Map — Intensity/Density
- **Keywords**: heatmap, intensity, matrix
- **Colors**: Cool (blue) to Hot (red), clear legend, divergent for +/- data
- **Perf**: Excellent (color CSS) | **A11y**: Pattern overlay for colorblind, numerical legend
- **Libraries**: D3.js, Plotly, ApexCharts

### 6. Choropleth/Bubble Map — Geographic
- **Colors**: Single color gradient or categorized, clear scale legend
- **Perf**: Moderate (rendering) | **A11y**: Text labels for regions, data table alternative
- **Libraries**: D3.js, Mapbox, Leaflet

### 7. Funnel/Sankey — Flow
- **Colors**: Stage gradient (start → end color), show conversion %
- **Perf**: Good | **A11y**: Clear stage labels + percentages
- **Libraries**: D3.js, Recharts, Custom SVG

### 8. Gauge/Bullet — Performance vs Target
- **Colors**: Red → Yellow → Green gradient, target marker line
- **Perf**: Good | **A11y**: Add numerical value + percentage label
- **Libraries**: D3.js, ApexCharts, Custom SVG

### 9. Line + Confidence Band — Forecast
- **Colors**: Actual solid #0080FF, Forecast dashed #FF9500, Band light shading
- **A11y**: Clearly distinguish actual vs forecast, add legend

### 10. Line + Highlights — Anomaly Detection
- **Colors**: Normal blue #0080FF, Anomaly red #FF0000 circle marker + alert
- **A11y**: Circle marker for anomalies, add text alert annotation

### 11. Treemap — Hierarchical/Nested
- **Colors**: Parent distinct hues, children lighter shades, white borders 2-3px
- **Perf**: Moderate | **A11y**: Poor — provide table alternative, label large areas
- **Libraries**: D3.js, Recharts, ApexCharts

### 12. Sankey Diagram — Flow/Process
- **Colors**: Gradient from source to target, opacity 0.4-0.6 for flows
- **A11y**: Poor — provide flow table alternative
- **Libraries**: D3.js (d3-sankey), Plotly

### 13. Waterfall Chart — Cumulative Changes
- **Colors**: Increases #4CAF50 green, Decreases #F44336 red, Start #2196F3, End #0D47A1
- **A11y**: Good — clear directional colors with labels
- **Libraries**: ApexCharts, Highcharts, Plotly

### 14. Radar/Spider — Multi-Variable Comparison
- **Colors**: Single #0080FF 20% fill, multiple: distinct colors per dataset
- **Limit**: 5-8 axes | **A11y**: Moderate — add data table
- **Libraries**: Chart.js, Recharts, ApexCharts

### 15. Candlestick — Stock/OHLC
- **Colors**: Bullish #26A69A green, Bearish #EF5350 red, Volume 40% opacity
- **A11y**: Moderate — provide OHLC data table
- **Libraries**: Lightweight Charts (TradingView), ApexCharts

### 16. Network Graph — Relationships
- **Colors**: Node types categorical, Edges #90A4AE 60% opacity
- **Perf**: Poor (500+ nodes struggles) | **A11y**: Very poor — provide adjacency list
- **Libraries**: D3.js (d3-force), Vis.js, Cytoscape.js

### 17. Box Plot — Distribution
- **Colors**: Box #BBDEFB, Border #1976D2, Median #D32F2F, Outliers #F44336
- **A11y**: Good — include stats table (min, Q1, median, Q3, max)
- **Libraries**: Plotly, D3.js, Chart.js (plugin)

### 18. Bullet Chart — Compact Performance vs Target
- **Colors**: Ranges #FFCDD2, #FFF9C4, #C8E6C9, Performance #1976D2, Target black 3px
- **Perf**: Excellent | **A11y**: Excellent — compact with clear values

### 19. Waffle Chart — Proportional/Percentage
- **Colors**: 10x10 grid, 3-5 categories max, 2-3px spacing
- **A11y**: Better than pie for accessibility
- **Libraries**: D3.js, React-Waffle, Custom CSS Grid

### 20. Sunburst — Hierarchical Proportional
- **Colors**: Center to outer: darker to lighter, 15-20% lighter per level
- **A11y**: Poor — provide hierarchy table alternative
- **Libraries**: D3.js (d3-hierarchy), Recharts, ApexCharts

### 21. Decomposition Tree — Root Cause Analysis
- **Colors**: Nodes #2563EB Primary vs #EF4444 Negative, Connectors neutral grey
- **Libraries**: Power BI (native), React-Flow, Custom D3.js

### 22. 3D Scatter/Surface — Spatial Data
- **Colors**: Depth cues via lighting/shading, Z-axis cool-to-warm gradient
- **Perf**: Heavy (WebGL required) | **A11y**: Poor — requires 2D alternative
- **Libraries**: Three.js, Deck.gl, Plotly 3D

### 23. Streaming Area — Real-Time
- **Colors**: Current bright pulse #00FF00, History fading opacity, Grid dark
- **Perf**: Optimized (canvas/webgl) | **A11y**: Provide pause button, high contrast
- **Libraries**: D3.js (smoothed), CanvasJS

### 24. Word Cloud — Sentiment/Emotion
- **Colors**: Positive #22C55E, Negative #EF4444, Neutral #94A3B8, Size = Frequency
- **A11y**: Poor for screen readers — use list view
- **Libraries**: D3-cloud, Highcharts, Nivo

### 25. Process Map — Process Mining
- **Colors**: Happy path #10B981 thick, Deviations #F59E0B thin, Bottlenecks #EF4444
- **Libraries**: React-Flow, Cytoscape.js, Recharts

## Accessibility Rules for All Charts

1. Provide data table alternative
2. Color is NOT the only indicator — use patterns, labels, shapes
3. Minimum 4.5:1 contrast for text on chart backgrounds
4. Include clear legends with text labels
5. Support keyboard navigation for interactive charts
6. Respect prefers-reduced-motion for animated charts

## CLI Search

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<data type>" --domain chart
```
