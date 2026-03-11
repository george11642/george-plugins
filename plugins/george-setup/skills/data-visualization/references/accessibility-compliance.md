# Accessibility Compliance for Data Visualization

WCAG 2.1 Level AA standards applied to charts, color blindness accommodation, screen reader support, interactive accessibility, and alt text templates.

---

## WCAG 2.1 Level AA Checklist for Charts

Apply to every visualization, not just when explicitly asked.

### Perceivable

- [ ] **1.1.1 Non-text Content**: Every chart image has descriptive alt text. See templates below.
- [ ] **1.4.1 Use of Color**: Information is never conveyed by color alone. Use patterns, labels, shapes, or direct annotations alongside color.
- [ ] **1.4.3 Contrast (Text)**: 4.5:1 minimum for regular text (axis labels, tick labels, legends). 3:1 for large text (18pt+ or 14pt+ bold).
- [ ] **1.4.11 Non-text Contrast**: 3:1 minimum for graphical elements (data points, chart borders, axis lines) against adjacent colors.
- [ ] **1.4.4 Resize Text**: Axis and legend labels must remain readable at 200% zoom.

### Operable

- [ ] **2.1.1 Keyboard**: All interactive chart features reachable by keyboard alone (Tab, arrow keys). Plotly has built-in keyboard nav.
- [ ] **2.4.6 Headings**: Chart containers have heading or title elements.

### Understandable

- [ ] **3.3.2 Labels or Instructions**: Axes are labeled with units. Color bars/legends have descriptive titles.

### Robust

- [ ] **4.1.2 Name, Role, Value**: SVG charts have `role="img"` and `aria-label`. Interactive controls have accessible names.

---

## Contrast Ratio Quick Reference

| Element | WCAG Requirement | Tool to Check |
|---|---|---|
| Axis tick labels | 4.5:1 vs background | WebAIM Contrast Checker |
| Legend text | 4.5:1 vs background | Coblis, Color Oracle |
| Chart title | 4.5:1 vs background | Browser DevTools |
| Data point markers | 3:1 vs adjacent color | APCA Contrast Calculator |
| Grid lines | 3:1 vs plot background | Can be lighter if decorative |
| Color bar / legend patches | 3:1 between adjacent steps | Verify at 3 steps apart |

**Test with grayscale**: Convert chart to grayscale. If you can still distinguish all data series, color usage is accessible.

---

## Color Blindness — Types and Accommodations

About 8% of men and 0.5% of women have color vision deficiency.

| Type | Prevalence | Cannot Distinguish | Use Instead |
|---|---|---|---|
| Deuteranopia/anomaly | ~6% of men | Red vs Green | Blue vs Orange/Yellow |
| Protanopia/anomaly | ~2% of men | Red vs Green (red dim) | Blue vs Orange/Yellow |
| Tritanopia | Rare | Blue vs Yellow | Red vs Green (with patterns) |
| Achromatopsia | Very rare | All colors | Shape/pattern only |

**Never use**: Red + Green as the only distinguishing factor (traffic light charts, positive/negative profit charts without redundant encoding).

---

## Colorblind-Safe Palettes

### Okabe-Ito (Recommended — works for all three dichromacy types)

```python
OKABE_ITO = [
    "#E69F00",  # orange
    "#56B4E9",  # sky blue
    "#009E73",  # bluish green
    "#F0E442",  # yellow
    "#0072B2",  # blue
    "#D55E00",  # vermillion
    "#CC79A7",  # reddish purple
    "#000000",  # black
]

# Use in matplotlib
import matplotlib.pyplot as plt
plt.rcParams["axes.prop_cycle"] = plt.cycler(color=OKABE_ITO)

# Use in seaborn
import seaborn as sns
sns.set_palette(OKABE_ITO)

# Use in Plotly
import plotly.express as px
fig = px.bar(df, x="category", y="value",
             color="group",
             color_discrete_sequence=OKABE_ITO)
```

### IBM Color Blind Safe Palette

```python
IBM_PALETTE = ["#648FFF", "#785EF0", "#DC267F", "#FE6100", "#FFB000"]
```

### ColorBrewer Safe Palettes

```python
# For sequential data (accessible)
COLORBREWER_SEQUENTIAL = {
    "blues":   ["#f7fbff","#deebf7","#c6dbef","#9ecae1","#6baed6","#4292c6","#2171b5","#08519c","#08306b"],
    "greens":  ["#f7fcf5","#e5f5e0","#c7e9c0","#a1d99b","#74c476","#41ab5d","#238b45","#006d2c","#00441b"],
    "ylgnbu":  ["#ffffd9","#edf8b1","#c7e9b4","#7fcdbb","#41b6c4","#1d91c0","#225ea8","#253494","#081d58"],
}

# For diverging data (accessible)
COLORBREWER_DIVERGING = {
    "piyg":   ["#8e0152","#c51b7d","#de77ae","#f1b6da","#fde0ef","#f7f7f7","#e6f5d0","#b8e186","#7fbc41","#4d9221","#276419"],
    "brbg":   ["#543005","#8c510a","#bf812d","#dfc27d","#f6e8c3","#f5f5f5","#c7eae5","#80cdc1","#35978f","#01665e","#003c30"],
}
```

### Matplotlib Built-In Safe Options

```python
# Best for continuous/sequential data
"viridis"   # yellow-green-blue, perceptually uniform
"cividis"   # yellow-blue, explicitly optimized for color blindness
"inferno"   # black-red-yellow, high contrast
"magma"     # similar to inferno

# Avoid
"jet"       # creates false boundaries, fails deuteranopia
"rainbow"   # same issues as jet
"hot"       # red-green-blue confused by deuteranopes
```

---

## Never Rely on Color Alone — Redundant Encoding

```python
import matplotlib.pyplot as plt
import numpy as np

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

categories = ["Group A", "Group B", "Group C", "Group D"]
values = [25, 42, 18, 35]
colors = OKABE_ITO[:4]

# BAD: Color only
axes[0].bar(categories, values, color=colors)
axes[0].set_title("INACCESSIBLE: Color Only")

# GOOD: Color + pattern + label
hatches = ["", "///", "...", "xxx"]
for i, (cat, val, color, hatch) in enumerate(zip(categories, values, colors, hatches)):
    bar = axes[1].bar(cat, val, color=color, hatch=hatch, edgecolor="black", linewidth=0.8)
    axes[1].text(i, val + 0.5, str(val), ha="center", va="bottom", fontweight="bold")

axes[1].set_title("ACCESSIBLE: Color + Pattern + Labels")

plt.tight_layout()
```

---

## Testing Tools

| Tool | Type | Use For |
|---|---|---|
| **Coblis** (coblis.coloring.nl) | Web | Simulate any color blindness type on screenshot |
| **Color Oracle** | Desktop app | Real-time screen filter for deuteranopia/protanopia/tritanopia |
| **WebAIM Contrast Checker** | Web | Enter hex colors, get contrast ratio |
| **APCA Contrast** (apcacontrast.com) | Web | Advanced perceptual contrast (WCAG 3.0 preview) |
| `matplotlib` grayscale test | Code | `fig.savefig('gray.png'); plt.imread(); matplotlib.cm.gray` |
| Browser DevTools Accessibility | Browser | Inspect computed roles, check contrast |

### Programmatic contrast check

```python
def relative_luminance(hex_color):
    """WCAG relative luminance of a hex color."""
    hex_color = hex_color.lstrip("#")
    r, g, b = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]

    def linearize(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)

def contrast_ratio(hex1, hex2):
    l1 = relative_luminance(hex1)
    l2 = relative_luminance(hex2)
    lighter, darker = max(l1, l2), min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)

# Check palette against white background
for name, color in zip(["orange", "sky blue", "green"], OKABE_ITO[:3]):
    ratio = contrast_ratio(color, "#FFFFFF")
    status = "PASS" if ratio >= 3.0 else "FAIL"
    print(f"{name} ({color}) vs white: {ratio:.2f}:1 — {status}")
```

---

## Screen Reader and ARIA Support

### Plotly (HTML/JS)

```python
import plotly.express as px

fig = px.bar(df, x="category", y="value", title="Sales by Category")

# Add description for screen readers
fig.update_layout(
    meta=dict(
        description=(
            "Bar chart showing sales by category. "
            "Electronics leads at $450K, followed by Clothing at $320K."
        )
    )
)

# When embedding in HTML, wrap with:
# <div role="img" aria-label="Bar chart showing sales by category...">
#   <div id="plotly-chart"></div>
# </div>
```

### Matplotlib (saved as image)

```python
# Alt text in HTML img tag (handled in embedding, not matplotlib itself)
fig.savefig("chart.png")

# Document the alt text alongside the image
alt_text = (
    "Bar chart showing quarterly revenue for 2024. "
    "Q4 was the highest at $2.3M. Q1 was the lowest at $1.4M."
)
# Store in a sidecar or return with figure for use in HTML/docs
```

### SVG Accessibility

```python
# matplotlib can save SVG with accessible title/desc
import xml.etree.ElementTree as ET

fig.savefig("chart.svg")

# Post-process SVG to add ARIA elements
tree = ET.parse("chart.svg")
root = tree.getroot()
ns = "http://www.w3.org/2000/svg"

# Add role="img"
root.set("role", "img")
root.set("aria-labelledby", "chart-title chart-desc")

# Add <title> and <desc> elements
title_el = ET.SubElement(root, f"{{{ns}}}title", {"id": "chart-title"})
title_el.text = "Quarterly Revenue 2024"
desc_el = ET.SubElement(root, f"{{{ns}}}desc", {"id": "chart-desc"})
desc_el.text = "Bar chart showing Q4 as highest at $2.3M, Q1 as lowest at $1.4M."

tree.write("chart_accessible.svg")
```

---

## Interactive Accessibility — Keyboard Navigation

Plotly charts support keyboard navigation by default when rendered in HTML:

- **Tab**: Focus chart
- **Arrow keys**: Navigate between data points
- **Enter**: Select a data point
- **Escape**: Deselect

```python
# Ensure charts are focusable in Dash
app.layout = html.Div([
    dcc.Graph(
        id="chart",
        figure=fig,
        config={
            "displayModeBar": True,    # keep toolbar for screen reader users
            "modeBarButtonsToRemove": ["lasso2d", "select2d"]
        },
        tabIndex=0,                    # make div focusable
        aria_label="Interactive chart: Sales by Quarter 2024"
    )
])
```

---

## Alt Text Templates

Use these templates every time you save a chart as an image.

### Bar Chart
```
"Bar chart showing [metric] by [category/time period].
[Highest-value category] leads at [value].
[Second] follows at [value].
[Optional: trend or key finding]."
```
Example: "Bar chart showing monthly website visits by channel for 2024. Organic search leads at 145K visits in March. Paid search follows at 89K. Direct traffic has grown steadily since January."

### Line Chart
```
"Line chart showing [metric] from [start date] to [end date].
[Number] lines represent [what each line is].
[Trend description, e.g., 'Values increased 34% over the period'].
[Any notable anomalies or peaks]."
```

### Pie / Donut Chart
```
"Pie chart showing [what the breakdown represents].
[Largest segment] represents [X%].
[Second segment] accounts for [Y%].
[Remaining segments listed if fewer than 5, otherwise 'Other segments account for Z%']."
```

### Scatter Plot
```
"Scatter plot showing the relationship between [x variable] and [y variable]
for [N] [data points / observations / samples].
[Describe correlation: 'A positive correlation is visible' / 'No clear pattern'].
[Highlight outliers or clusters if present]."
```

### Heatmap
```
"Heatmap showing [metric] across [row dimension] (rows) and [column dimension] (columns).
Darker [color] indicates [higher/lower] values.
[Highest-value cell] is [value] at [row, column].
[Any visible pattern: diagonal, cluster, row/column dominance]."
```

### Map (Choropleth)
```
"Choropleth map showing [metric] by [geographic unit: country/state/county].
[Geographic region] has the highest value at [X].
[Geographic region] has the lowest value at [Y].
[Color scale: 'Darker orange indicates higher rates']."
```

---

## Focus Management in Dash Callbacks

```python
from dash import clientside_callback, Output, Input

# Announce updates to screen reader users
app.layout = html.Div([
    dcc.Graph(id="chart"),
    html.Div(id="sr-announcement",
             **{"aria-live": "polite", "aria-atomic": "true"},
             style={"position": "absolute", "left": "-9999px"})
])

@app.callback(
    Output("sr-announcement", "children"),
    Input("chart", "relayoutData")
)
def announce_update(relayout):
    if relayout:
        return "Chart has been updated with new data."
    return ""
```
