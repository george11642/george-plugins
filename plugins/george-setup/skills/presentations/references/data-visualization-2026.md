# Data Visualization for Presentations (2026)

Presentation data viz is NOT dashboard design. A presentation chart communicates ONE point to a live audience in 30 seconds. This reference covers modern chart selection, simplification principles, and styling for 2026.

---

## The 2026 Simplification Principle

The defining data visualization trend of 2026 is radical simplification. Audiences process one data point per chart. Everything else is noise.

### Core Rules

1. **One key data point per slide** — not a dashboard, not a data table
2. **50%+ white space around charts** — charts need breathing room to read fast
3. **Direct labels eliminate legends** — label every data point directly; remove the legend entirely
4. **No decorative elements** — no 3D, no gradients on bars, no drop shadows on charts
5. **Single accent color** — chart series are gray except the one the presenter is talking about

### The "Taxi Test"

Can someone understand this chart while reading it in the back of a moving taxi in 10 seconds?

- If no: simplify further
- If yes: the chart is presentation-ready

---

## Recommended Chart Types for Presentations

### Donut Charts — Single Metric Composition

Use when: showing one category's proportion of a whole (40%, 73%, etc.)

Do NOT use for: comparing multiple categories (use bars) or showing change over time (use lines).

```python
# python-pptx donut chart
from pptx.chart.data import ChartData
from pptx.enum.chart import XL_CHART_TYPE

chart_data = ChartData()
chart_data.categories = ['Target Group', 'Other']
chart_data.add_series('Proportion', (73, 27))

chart = slide.shapes.add_chart(
    XL_CHART_TYPE.DOUGHNUT,
    left, top, width, height,
    chart_data
).chart

chart.chart_style = 2
# Set hole size (doughnut_hole_size)
chart.plots[0].doughnut_hole_size = 60  # 60% hole = modern donut

# Color: accent on key slice, light gray on remainder
from pptx.dml.color import RGBColor
points = chart.plots[0].series[0].points
points[0].format.fill.solid()
points[0].format.fill.fore_color.rgb = RGBColor(0x15, 0x65, 0xC0)  # accent
points[1].format.fill.solid()
points[1].format.fill.fore_color.rgb = RGBColor(0xE0, 0xE0, 0xE0)  # gray
```

**HTML/CSS donut (no library needed):**
```html
<div class="donut-wrapper">
  <svg viewBox="0 0 100 100" class="donut" width="300" height="300">
    <!-- Background circle -->
    <circle cx="50" cy="50" r="40" fill="none"
            stroke="#E0E0E0" stroke-width="20"/>
    <!-- Value arc: circumference = 2π×40 ≈ 251.3 -->
    <!-- For 73%: stroke-dasharray = 251.3*0.73 251.3 -->
    <circle cx="50" cy="50" r="40" fill="none"
            stroke="#1565C0" stroke-width="20"
            stroke-dasharray="183.5 251.3"
            stroke-dashoffset="62.8"
            transform="rotate(-90, 50, 50)"/>
    <!-- Center label -->
    <text x="50" y="46" text-anchor="middle"
          font-size="20" font-weight="900" fill="#1565C0">73%</text>
    <text x="50" y="60" text-anchor="middle"
          font-size="7" fill="#666" text-transform="uppercase">Completion</text>
  </svg>
</div>
```

---

### Sankey Diagrams — Flow and Transitions

Use when: showing how things flow from source to destination (user journeys, budget allocation, energy flows, funnel stages with branching).

**Key rules for presentation Sankeys:**
- Maximum 5 source nodes + 5 destination nodes (10 nodes total)
- Label every node AND every flow value
- Use gradient fills to show direction
- Remove all gridlines and axes

```python
# Plotly Sankey (save to image for embedding)
import plotly.graph_objects as go

fig = go.Figure(go.Sankey(
    node=dict(
        pad=15, thickness=20,
        line=dict(color="black", width=0.5),
        label=["Awareness", "Consideration", "Trial", "Purchase", "Retained", "Churned"],
        color=["#90CAF9", "#64B5F6", "#42A5F5", "#1565C0", "#0D47A1", "#EF9A9A"]
    ),
    link=dict(
        source=[0, 0, 1, 1, 2, 2, 3, 3],
        target=[1, 5, 2, 5, 3, 5, 4, 5],
        value= [800, 200, 600, 200, 400, 200, 300, 100],
        color=["rgba(21,101,192,0.2)"] * 8
    )
))
fig.update_layout(
    font_size=14, font_family="Inter",
    margin=dict(l=20, r=20, t=20, b=20),
    paper_bgcolor='rgba(0,0,0,0)',
    plot_bgcolor='rgba(0,0,0,0)'
)
fig.write_image("sankey.png", width=800, height=400, scale=2)
```

---

### Simplified Funnels — Stage Progression

Use when: showing conversion through sequential stages (sales funnel, clinical trial stages, hiring pipeline).

**2026 funnel design rules:**
- Show absolute numbers AND percentages
- Use HORIZONTAL funnels for presentations (easier to read left-to-right)
- Maximum 5 stages
- Color: full opacity on first bar, progressively lighter to show attrition

```html
<!-- Clean horizontal funnel (HTML) -->
<div class="funnel">
  <div class="stage" style="--pct: 100%; --color: #1565C0">
    <span class="label">Awareness</span>
    <div class="bar"><span>10,000</span></div>
    <span class="pct">100%</span>
  </div>
  <div class="stage" style="--pct: 65%; --color: #1976D2">
    <span class="label">Consideration</span>
    <div class="bar"><span>6,500</span></div>
    <span class="pct">65%</span>
  </div>
  <div class="stage" style="--pct: 42%; --color: #1E88E5">
    <span class="label">Trial</span>
    <div class="bar"><span>4,200</span></div>
    <span class="pct">42%</span>
  </div>
  <div class="stage" style="--pct: 18%; --color: #42A5F5">
    <span class="label">Purchase</span>
    <div class="bar"><span>1,800</span></div>
    <span class="pct">18%</span>
  </div>
</div>
<style>
.funnel { display: flex; flex-direction: column; gap: 8px; padding: 20px; }
.stage  { display: flex; align-items: center; gap: 12px; }
.bar    {
  height: 44px; background: var(--color);
  width: var(--pct); border-radius: 4px;
  display: flex; align-items: center;
  padding: 0 12px; color: white; font-weight: 700; font-size: 18px;
  transition: width 0.6s ease;
}
.label { width: 140px; font-size: 14px; text-align: right; }
.pct   { font-size: 14px; opacity: 0.6; }
</style>
```

---

### Horizontal Bar Charts — Category Comparison

Horizontal bars are the default choice for comparing named categories. They are more readable than vertical bars because:
- Category labels fit naturally alongside bars (no 45° rotation)
- Audiences read left-to-right and top-to-bottom — horizontal bars match this
- More space for longer category names
- Easier to rank visually

```python
# python-pptx horizontal bar chart with direct labels
from pptx.chart.data import ChartData
from pptx.enum.chart import XL_CHART_TYPE, XL_LABEL_POSITION

chart_data = ChartData()
chart_data.categories = ['Category A', 'Category B', 'Category C', 'Category D']
chart_data.add_series('Values', (87, 72, 58, 41))

chart = slide.shapes.add_chart(
    XL_CHART_TYPE.BAR_CLUSTERED,   # BAR_CLUSTERED = horizontal
    left, top, width, height, chart_data
).chart

# Remove gridlines and axes
chart.value_axis.major_gridlines.format.line.fill.background()
chart.value_axis.visible = False

# Enable outside-end data labels
plot = chart.plots[0]
plot.has_data_labels = True
plot.data_labels.show_value = True
plot.data_labels.position = XL_LABEL_POSITION.OUTSIDE_END
plot.data_labels.font.size = Pt(14)
plot.data_labels.font.bold = True

# Single accent on highest value
for i, point in enumerate(plot.series[0].points):
    point.format.fill.solid()
    if i == 0:  # highest value (first in descending order)
        point.format.fill.fore_color.rgb = RGBColor(0x15, 0x65, 0xC0)
    else:
        point.format.fill.fore_color.rgb = RGBColor(0xCC, 0xCC, 0xCC)
```

---

### Dot Plots — Distribution Without Bars

Dot plots show individual data points or means without implying continuous distribution. Use instead of bar charts when:
- Comparing group means with high variance
- Showing individual observations
- Avoiding "bars imply proportional data" misinterpretation

```python
# matplotlib dot plot → save to image
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

fig, ax = plt.subplots(figsize=(8, 4))

categories = ['Group A', 'Group B', 'Group C', 'Group D']
values = [72, 58, 84, 45]

# Draw track lines
for i, (cat, val) in enumerate(zip(categories, values)):
    ax.hlines(i, 0, 100, colors='#EEEEEE', linewidth=1.5)
    # Accent the highest
    color = '#1565C0' if val == max(values) else '#9E9E9E'
    ax.scatter(val, i, s=200, color=color, zorder=5)
    ax.text(val + 2, i, f'{val}', va='center', fontsize=12,
            color=color, fontweight='bold' if val == max(values) else 'normal')

ax.set_yticks(range(len(categories)))
ax.set_yticklabels(categories, fontsize=12)
ax.set_xlim(0, 110)
ax.set_xlabel('')
ax.spines[:].set_visible(False)
ax.tick_params(left=False, bottom=False)
ax.set_xticks([])
plt.tight_layout()
plt.savefig('dot_plot.png', dpi=150, bbox_inches='tight',
            transparent=True)
plt.close()
```

---

## Anti-Patterns to Eliminate

### 3D Effects

3D bars, 3D pies, and 3D surfaces distort the perceived proportions of data. A bar that is 50% as tall as another looks taller than 50% when viewed in 3D perspective.

**Never use:**
- `XL_CHART_TYPE.BAR_3D_CLUSTERED`
- `XL_CHART_TYPE.PIE_3D`
- `XL_CHART_TYPE.COLUMN_3D_CLUSTERED`
- 3D surface plots in presentations

### Multiple Metrics on One Chart

A chart with 4 series, 2 axes, and a trend line is a dashboard chart, not a presentation chart.

**Rule:** One series, or two at most for before/after comparison.

### Dual-Axis Charts

Dual-axis charts (two different Y-axes) are almost always misread. Audiences map them incorrectly.

If you need to compare two metrics:
- Use two separate charts side by side
- Normalize both to an index (both start at 100)
- Use a scatter plot if the relationship IS the point

### Dense Gridlines

Gridlines serve analysts, not audiences. In presentations, they compete with the data for attention.

```python
# Remove all gridlines
chart.value_axis.major_gridlines.format.line.fill.background()
chart.value_axis.minor_gridlines.format.line.fill.background()
chart.category_axis.major_gridlines.format.line.fill.background()
```

### Legend-Only Labeling

If the audience must look back and forth between a legend and the chart to decode it, the cognitive load is too high for a live presentation.

**Always** use direct labels. Remove the legend.

```python
chart.has_legend = False
chart.plots[0].has_data_labels = True
chart.plots[0].data_labels.show_series_name = True  # label includes series name
chart.plots[0].data_labels.show_value = True
```

---

## Styling Rules

### Single Accent Color for Emphasis

```python
# Monochrome with single accent — the standard 2026 approach
ACCENT = RGBColor(0x15, 0x65, 0xC0)  # blue
BASE   = RGBColor(0xCC, 0xCC, 0xCC)  # light gray

highlight_index = 2  # which bar/point to highlight

for i, point in enumerate(series.points):
    point.format.fill.solid()
    point.format.fill.fore_color.rgb = ACCENT if i == highlight_index else BASE
```

### Oversized Data Labels for Key Numbers

When a slide's entire purpose is to show one number, make it massive:

```python
# 100pt+ for hero metric
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN

txBox = slide.shapes.add_textbox(
    Inches(0.5), Inches(1.5),
    Inches(12.3), Inches(3.5)
)
tf = txBox.text_frame
p = tf.paragraphs[0]
p.alignment = PP_ALIGN.CENTER
run = p.add_run()
run.text = "94%"
run.font.size = Pt(120)
run.font.bold = True
run.font.color.rgb = RGBColor(0x15, 0x65, 0xC0)

# Small descriptor below
p2 = tf.add_paragraph()
p2.alignment = PP_ALIGN.CENTER
r2 = p2.add_run()
r2.text = "USER SATISFACTION"
r2.font.size = Pt(16)
r2.font.color.rgb = RGBColor(0x66, 0x66, 0x66)
```

### Remove Redundant Text

Every text element on a chart should pass the "removal test": if removing it makes the chart harder to understand, keep it. If removing it makes no difference (or the chart is easier to read), remove it.

Common removals:
- Chart title (the slide title already says what the chart shows)
- Axis titles (obvious from context)
- Gridlines (direct labels make them redundant)
- Legend (replaced by direct labels)

### Rounded Corners on Bars

Rounded corners on bars make charts feel modern and approachable. This requires OOXML editing in python-pptx (not exposed in the API directly):

```python
# Access chart XML to add rounded bar corners
from pptx.oxml.ns import qn
from lxml import etree

chart_part = chart.part
chart_xml = chart_part._element

# Find bar chart series and add rounding via spPr
for ser in chart_xml.findall('.//' + qn('c:ser')):
    spPr = ser.find(qn('c:spPr'))
    if spPr is None:
        spPr = etree.SubElement(ser, qn('c:spPr'))
    # Add rounded solid fill
    solidFill = etree.SubElement(spPr, qn('a:solidFill'))
    srgbClr = etree.SubElement(solidFill, qn('a:srgbClr'))
    srgbClr.set('val', '1565C0')
```

### Minimal Axis Labels

Keep only the labels that cannot be inferred:
- Y-axis: remove label and title if bars have direct value labels
- X-axis: keep category labels (needed for horizontal bars)
- Units: add once in the chart title or a small caption, not on every tick

```python
# Minimal axis setup
value_axis = chart.value_axis
value_axis.visible = False          # hide entirely if direct labels present
value_axis.has_title = False

category_axis = chart.category_axis
category_axis.has_title = False
category_axis.tick_labels.font.size = Pt(12)
```

---

## Chart Type Quick Reference

| Goal | Chart Type | Max Data Points | Notes |
|------|-----------|-----------------|-------|
| Show one proportion | Donut | 2 (value + remainder) | Label the key percentage in center |
| Compare categories | Horizontal bar | 5-7 | Sort descending; accent top bar |
| Show flow/transitions | Sankey | 10 nodes max | Label all flows |
| Show stage conversion | Funnel | 5 stages max | Show % AND absolute |
| Show distribution | Dot plot | 20 points max | Better than histograms for presentations |
| Show trend over time | Line chart | 2-3 series max | Direct labels at endpoints |
| Show relationship | Scatter | 20-50 points | Add trend line + R² if relevant |
| Show single hero metric | Text + oversized number | 1 | 100pt+ font, no chart needed |

---

## html2pptx Integration

For charts created in HTML/JS (D3, Chart.js, Plotly), convert to PPTX via html2pptx:

```javascript
// html2pptx — chart slide
const slides = [
  {
    html: `
      <div style="width:1280px;height:720px;background:white;padding:60px">
        <h1 style="font:700 48px Inter;color:#212121;margin-bottom:20px">
          Q3 Performance
        </h1>
        <canvas id="chart" width="1160" height="520"></canvas>
      </div>
    `,
    script: `
      new Chart(document.getElementById('chart'), {
        type: 'bar',
        data: {
          labels: ['Jan', 'Feb', 'Mar'],
          datasets: [{
            data: [42, 58, 73],
            backgroundColor: ['#CCCCCC', '#CCCCCC', '#1565C0'],
            borderRadius: 6
          }]
        },
        options: {
          plugins: { legend: { display: false } },
          scales: { y: { display: false }, x: { grid: { display: false } } }
        }
      });
    `
  }
];
```
