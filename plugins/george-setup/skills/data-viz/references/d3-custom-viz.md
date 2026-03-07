# D3.js Custom Visualization Reference

Covers the D3 vs Plotly decision tree, D3 fundamentals (selections, data binding, enter/update/exit), scales, axes, force-directed graphs, custom tooltips, responsive SVG, performance for large datasets, and D3 with React.

---

## D3 vs Plotly Decision Tree

```
Do you need this chart?
  Standard type (bar, line, scatter, pie, heatmap, choropleth) →
    Python / Jupyter → Plotly Express (px.*)
    Web app (React/Vue) → Plotly.js or Recharts
    Dashboard with callbacks → Plotly Dash (Python) or Recharts (React)

  Non-standard / custom layout needed →
    Radial layout, custom hierarchy, bespoke chart type → D3.js
    Force simulation (physics-based positioning) → D3.js
    Animated transitions (enter/update/exit with custom easing) → D3.js
    Full SVG/canvas control required → D3.js
    Reusable chart library you're building → D3.js

  Biological network / pathway diagram → Cytoscape.js (uses D3 internally)
  Large graph (>10k nodes) with canvas → D3 with canvas renderer

Summary rule: Plotly when speed matters; D3 when design matters.
```

| Factor | Plotly | D3.js |
|---|---|---|
| Learning curve | Low (px) → Medium (go) | High |
| Standard charts | Excellent built-in | DIY |
| Custom layouts | Limited | Complete control |
| Python integration | Native | JS only (or pyodide) |
| Animation control | Declarative frames | Fine-grained transitions |
| Performance (>10k pts) | WebGL (scattergl) | Canvas mode |
| Mobile touch | Built-in | Manual |
| Accessibility | Partial (ARIA via meta) | Full control |

---

## 1. D3 Fundamentals — Selections and Data Binding

```javascript
// Include: <script src="https://cdn.jsdelivr.net/npm/d3@7"></script>

// Selection: wrap DOM elements
const svg = d3.select("#chart");               // single element
const circles = d3.selectAll("circle");        // all matching elements

// Data binding: join array to selection
const data = [10, 30, 50, 20, 40];

// enter() = new elements needed
// update() = existing elements
// exit() = elements to remove

const circles = svg.selectAll("circle")
  .data(data)
  .join(
    enter  => enter.append("circle")
                   .attr("r", 0)              // start small
                   .call(enter => enter.transition().duration(500).attr("r", d => d)),
    update => update.call(update => update.transition().duration(300).attr("r", d => d)),
    exit   => exit.call(exit => exit.transition().duration(200).attr("r", 0).remove())
  )
  .attr("cx", (d, i) => i * 60 + 30)
  .attr("cy", 100)
  .attr("fill", "steelblue");
```

### Key/identity binding (for stable transitions)

```javascript
// Use a key function to match data to elements by ID (not array index)
svg.selectAll("rect")
  .data(data, d => d.id)      // d.id is the key
  .join("rect")
  .attr("x", d => xScale(d.x))
  .attr("y", d => yScale(d.y));
```

---

## 2. Scale Functions

```javascript
// --- Linear scale (continuous → continuous) ---
const xScale = d3.scaleLinear()
  .domain([0, 100])          // input range (data space)
  .range([0, width])         // output range (pixel space)
  .clamp(true);              // don't extrapolate beyond domain

// --- Band scale (categorical → continuous) ---
const xBand = d3.scaleBand()
  .domain(["A", "B", "C", "D"])
  .range([0, width])
  .padding(0.2);             // gap between bands (0–1)
// xBand("B") → x position; xBand.bandwidth() → bar width

// --- Time scale ---
const xTime = d3.scaleTime()
  .domain([new Date("2024-01-01"), new Date("2024-12-31")])
  .range([0, width]);

// --- Log scale ---
const yLog = d3.scaleLog()
  .domain([1, 100000])
  .range([height, 0])
  .base(10);

// --- Color scale ---
const colorScale = d3.scaleSequential()
  .domain([0, 100])
  .interpolator(d3.interpolateViridis);

const colorOrdinal = d3.scaleOrdinal()
  .domain(["cat1", "cat2", "cat3"])
  .range(["#E69F00", "#56B4E9", "#009E73"]);  // Okabe-Ito
```

---

## 3. Axis Generation

```javascript
// Create axis generators
const xAxis = d3.axisBottom(xScale)
  .ticks(6)
  .tickFormat(d => `$${d3.format(",.0f")(d)}`);

const yAxis = d3.axisLeft(yScale)
  .ticks(5)
  .tickFormat(d3.format(".1%"));   // format as percentage

// Append axis group to SVG
const xAxisGroup = svg.append("g")
  .attr("class", "x-axis")
  .attr("transform", `translate(0, ${height})`)
  .call(xAxis);

const yAxisGroup = svg.append("g")
  .attr("class", "y-axis")
  .call(yAxis);

// Style axis
xAxisGroup.selectAll("text")
  .attr("font-size", "12px")
  .attr("fill", "#333");

xAxisGroup.select(".domain").attr("stroke", "#aaa");
xAxisGroup.selectAll(".tick line").attr("stroke", "#ddd");

// Gridlines (extend ticks across chart)
const yGrid = d3.axisLeft(yScale)
  .ticks(5)
  .tickSize(-width)   // negative = extends right across chart
  .tickFormat("");    // no labels (gridlines only)

svg.append("g").attr("class", "grid")
  .call(yGrid)
  .selectAll("line").attr("stroke", "#eee").attr("stroke-dasharray", "3,3");
```

---

## 4. Complete Minimal Bar Chart (~60 lines)

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>D3 Bar Chart</title>
  <script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
  <style>
    body { font-family: sans-serif; }
    .bar { fill: steelblue; transition: fill 0.2s; }
    .bar:hover { fill: #e74c3c; }
    .tooltip {
      position: absolute; background: rgba(0,0,0,0.8);
      color: white; padding: 6px 10px; border-radius: 4px;
      font-size: 12px; pointer-events: none; opacity: 0;
      transition: opacity 0.2s;
    }
  </style>
</head>
<body>
<div id="chart"></div>
<div class="tooltip" id="tooltip"></div>
<script>
const data = [
  { label: "Jan", value: 42 },
  { label: "Feb", value: 65 },
  { label: "Mar", value: 38 },
  { label: "Apr", value: 91 },
  { label: "May", value: 74 },
  { label: "Jun", value: 53 },
];

const margin = { top: 30, right: 20, bottom: 40, left: 50 };
const width  = 560 - margin.left - margin.right;
const height = 320 - margin.top  - margin.bottom;

const svg = d3.select("#chart")
  .append("svg")
  .attr("viewBox", `0 0 ${width + margin.left + margin.right} ${height + margin.top + margin.bottom}`)
  .attr("preserveAspectRatio", "xMidYMid meet")
  .attr("role", "img")
  .attr("aria-label", "Bar chart showing monthly values. April is highest at 91.")
  .append("g")
  .attr("transform", `translate(${margin.left},${margin.top})`);

const x = d3.scaleBand().domain(data.map(d => d.label)).range([0, width]).padding(0.25);
const y = d3.scaleLinear().domain([0, d3.max(data, d => d.value) * 1.1]).range([height, 0]);

// Axes
svg.append("g").attr("transform", `translate(0,${height})`).call(d3.axisBottom(x));
svg.append("g").call(d3.axisLeft(y).ticks(5));

// Y-axis label
svg.append("text")
  .attr("transform", "rotate(-90)")
  .attr("x", -height / 2).attr("y", -38)
  .attr("text-anchor", "middle").attr("font-size", 12)
  .text("Value");

const tooltip = d3.select("#tooltip");

// Bars
svg.selectAll(".bar")
  .data(data)
  .join("rect")
  .attr("class", "bar")
  .attr("x", d => x(d.label))
  .attr("y", height)             // start at bottom for enter animation
  .attr("width", x.bandwidth())
  .attr("height", 0)
  .attr("rx", 2)
  .on("mouseover", (event, d) => {
    tooltip.style("opacity", 1).html(`<strong>${d.label}</strong>: ${d.value}`);
  })
  .on("mousemove", (event) => {
    tooltip.style("left", (event.pageX + 12) + "px").style("top", (event.pageY - 28) + "px");
  })
  .on("mouseout", () => tooltip.style("opacity", 0))
  .transition().duration(600).delay((d, i) => i * 80)
  .attr("y", d => y(d.value))
  .attr("height", d => height - y(d.value));

// Title
svg.append("text")
  .attr("x", width / 2).attr("y", -8)
  .attr("text-anchor", "middle").attr("font-size", 15).attr("font-weight", "bold")
  .text("Monthly Values");
</script>
</body>
</html>
```

---

## 5. Force-Directed Graph Template (~80 lines)

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>D3 Force Graph</title>
  <script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
  <style>
    .link { stroke: #aaa; stroke-width: 1.5px; }
    .node { cursor: grab; }
    .node:active { cursor: grabbing; }
    .node circle { stroke: white; stroke-width: 1.5px; }
    .node text { font-size: 11px; pointer-events: none; }
  </style>
</head>
<body>
<svg id="graph" width="800" height="600"></svg>
<script>
const nodes = [
  { id: "A", group: 1 }, { id: "B", group: 1 }, { id: "C", group: 2 },
  { id: "D", group: 2 }, { id: "E", group: 3 }, { id: "F", group: 3 },
  { id: "Hub", group: 0 },
];
const links = [
  { source: "Hub", target: "A", value: 3 },
  { source: "Hub", target: "C", value: 2 },
  { source: "Hub", target: "E", value: 4 },
  { source: "A", target: "B", value: 1 },
  { source: "C", target: "D", value: 1 },
  { source: "E", target: "F", value: 1 },
  { source: "B", target: "D", value: 1 },
];

const svg = d3.select("#graph");
const width = +svg.attr("width"), height = +svg.attr("height");

const color = d3.scaleOrdinal(d3.schemeTableau10);

// Arrow marker for directed graphs (optional)
svg.append("defs").append("marker")
  .attr("id", "arrow").attr("viewBox", "0 -5 10 10")
  .attr("refX", 20).attr("markerWidth", 6).attr("markerHeight", 6)
  .attr("orient", "auto")
  .append("path").attr("d", "M0,-5L10,0L0,5").attr("fill", "#aaa");

// Force simulation
const simulation = d3.forceSimulation(nodes)
  .force("link",   d3.forceLink(links).id(d => d.id).distance(80).strength(0.5))
  .force("charge", d3.forceManyBody().strength(-300))   // repulsion
  .force("center", d3.forceCenter(width / 2, height / 2))
  .force("collision", d3.forceCollide(20));              // prevent overlap

// Links
const link = svg.append("g").selectAll("line")
  .data(links).join("line").attr("class", "link")
  .attr("stroke-width", d => Math.sqrt(d.value));

// Nodes (group = g element containing circle + label)
const node = svg.append("g").selectAll(".node")
  .data(nodes).join("g")
  .attr("class", "node")
  .call(d3.drag()
    .on("start", (event, d) => { if (!event.active) simulation.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; })
    .on("drag",  (event, d) => { d.fx = event.x; d.fy = event.y; })
    .on("end",   (event, d) => { if (!event.active) simulation.alphaTarget(0); d.fx = null; d.fy = null; })
  );

node.append("circle")
  .attr("r", d => d.id === "Hub" ? 18 : 10)
  .attr("fill", d => color(d.group));

node.append("text")
  .attr("dx", 14).attr("dy", "0.35em")
  .text(d => d.id);

node.append("title").text(d => d.id);   // native tooltip (accessible)

// Tick: update positions each simulation step
simulation.on("tick", () => {
  link
    .attr("x1", d => d.source.x).attr("y1", d => d.source.y)
    .attr("x2", d => d.target.x).attr("y2", d => d.target.y);
  node.attr("transform", d => `translate(${d.x},${d.y})`);
});
</script>
</body>
</html>
```

---

## 6. Custom Tooltip Patterns

```javascript
// Pattern 1: HTML tooltip div (most flexible)
const tooltip = d3.select("body").append("div")
  .attr("class", "d3-tooltip")
  .style("position", "absolute")
  .style("background", "rgba(0,0,0,0.85)")
  .style("color", "#fff")
  .style("padding", "8px 12px")
  .style("border-radius", "4px")
  .style("font-size", "13px")
  .style("pointer-events", "none")
  .style("opacity", 0);

selection.on("mouseover", (event, d) => {
    tooltip.transition().duration(150).style("opacity", 1);
    tooltip.html(`<strong>${d.name}</strong><br>${d.value.toLocaleString()}`);
  })
  .on("mousemove", (event) => {
    tooltip
      .style("left", `${event.pageX + 15}px`)
      .style("top",  `${event.pageY - 30}px`);
  })
  .on("mouseleave", () => {
    tooltip.transition().duration(200).style("opacity", 0);
  });

// Pattern 2: SVG foreignObject tooltip (stays in SVG coordinate space)
const svgTooltip = svg.append("foreignObject")
  .attr("width", 150).attr("height", 60)
  .style("visibility", "hidden");

svgTooltip.append("xhtml:div")
  .attr("class", "svg-tooltip");
```

---

## 7. Responsive SVG

Always use `viewBox` + `preserveAspectRatio` instead of fixed width/height on the SVG element.

```javascript
// Responsive container pattern
const container = document.getElementById("chart-container");
const margin = { top: 20, right: 20, bottom: 40, left: 50 };

// Get initial dimensions from container
let width  = container.clientWidth  - margin.left - margin.right;
let height = container.clientHeight - margin.top  - margin.bottom;

const svg = d3.select("#chart-container").append("svg")
  .attr("viewBox", `0 0 ${width + margin.left + margin.right} ${height + margin.top + margin.bottom}`)
  .attr("preserveAspectRatio", "xMidYMid meet")
  .style("width", "100%")
  .style("height", "auto");

// Resize observer — re-render on container resize
const resizeObserver = new ResizeObserver(() => {
  const newWidth = container.clientWidth - margin.left - margin.right;
  // Update scales and re-render
  xScale.range([0, newWidth]);
  svg.select(".x-axis").call(d3.axisBottom(xScale));
  svg.selectAll(".bar").attr("x", d => xScale(d.label)).attr("width", xScale.bandwidth());
});
resizeObserver.observe(container);
```

---

## 8. Performance for Large Datasets (>10k Nodes)

SVG becomes slow above ~5,000 elements. Use canvas for rendering, D3 for layout/interaction.

```javascript
// Canvas renderer with D3 scales
const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");
const pixelRatio = window.devicePixelRatio || 1;

canvas.width  = width  * pixelRatio;
canvas.height = height * pixelRatio;
canvas.style.width  = width  + "px";
canvas.style.height = height + "px";
ctx.scale(pixelRatio, pixelRatio);

function drawPoints(data) {
  ctx.clearRect(0, 0, width, height);

  for (const d of data) {
    ctx.beginPath();
    ctx.arc(xScale(d.x), yScale(d.y), 3, 0, 2 * Math.PI);
    ctx.fillStyle = colorScale(d.group);
    ctx.fill();
  }
}

drawPoints(data);  // renders 100k points in ~16ms vs ~500ms for SVG

// Interaction on canvas: use quadtree for nearest-neighbor lookup
const quadtree = d3.quadtree()
  .x(d => xScale(d.x))
  .y(d => yScale(d.y))
  .addAll(data);

canvas.addEventListener("mousemove", (event) => {
  const [mx, my] = d3.pointer(event, canvas);
  const nearest = quadtree.find(mx, my, 20);  // search radius = 20px
  if (nearest) showTooltip(nearest, event);
});
```

---

## 9. D3 with React (useRef + useEffect Pattern)

```jsx
import { useRef, useEffect } from "react";
import * as d3 from "d3";

function BarChart({ data, width = 500, height = 300 }) {
  const svgRef = useRef(null);

  const margin = { top: 20, right: 20, bottom: 40, left: 50 };
  const innerWidth  = width  - margin.left - margin.right;
  const innerHeight = height - margin.top  - margin.bottom;

  useEffect(() => {
    if (!svgRef.current || !data.length) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();  // clear on re-render

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3.scaleBand()
      .domain(data.map(d => d.label))
      .range([0, innerWidth])
      .padding(0.2);

    const y = d3.scaleLinear()
      .domain([0, d3.max(data, d => d.value)])
      .nice()
      .range([innerHeight, 0]);

    g.append("g").attr("transform", `translate(0,${innerHeight})`).call(d3.axisBottom(x));
    g.append("g").call(d3.axisLeft(y));

    g.selectAll("rect")
      .data(data)
      .join("rect")
      .attr("x", d => x(d.label))
      .attr("y", d => y(d.value))
      .attr("width", x.bandwidth())
      .attr("height", d => innerHeight - y(d.value))
      .attr("fill", "steelblue")
      .attr("rx", 2);

  }, [data, width, height]);  // re-render when data or dimensions change

  return (
    <svg
      ref={svgRef}
      width={width}
      height={height}
      role="img"
      aria-label="Bar chart"
    />
  );
}

export default BarChart;
```

**React + D3 rules**:
- D3 owns DOM mutations inside `useEffect`. React owns the `<svg>` ref.
- `svg.selectAll("*").remove()` on each render is safe for small charts.
- For large charts: use `useRef` to track previous data and only update changed elements.
- For animations: use `d3.transition()` inside `useEffect`, not React state transitions.

---

## 10. D3 Quick Reference

```javascript
// Useful utility functions
d3.extent(data, d => d.value)     // [min, max]
d3.sum(data, d => d.value)
d3.mean(data, d => d.value)
d3.median(data, d => d.value)
d3.rollup(data, v => v.length, d => d.category)  // group + aggregate

// Number formatting
d3.format(",.0f")(1234567)        // "1,234,567"
d3.format(".1%")(0.342)           // "34.2%"
d3.format(".2e")(12345)           // "1.23e+4"
d3.format("$,.2f")(1234.5)        // "$1,234.50"

// Date formatting
d3.timeFormat("%b %Y")(new Date()) // "Mar 2026"
d3.timeParse("%Y-%m-%d")("2024-06-15")  // Date object

// Color interpolation
d3.interpolateRgb("steelblue", "red")(0.5)  // midpoint color
d3.interpolateHsl("steelblue", "red")(0.5)  // smoother in HSL space
```
