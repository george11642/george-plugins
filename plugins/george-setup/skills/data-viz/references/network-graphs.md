# Network Graphs Reference

Covers Plotly Sankey diagrams, sunburst vs treemap, NetworkX + matplotlib, force-directed layouts, hierarchical graphs, and when to use each approach.

---

## Decision Tree

```
What relationship am I showing?
  FLOWS (money, traffic, energy moving between nodes) → Sankey diagram
  HIERARCHY (parent-child tree, taxonomy) →
    Proportional area matters? → Treemap
    Depth/radial layout preferred? → Sunburst
    Linear tree / dendrogram → Dendrogram (scipy + matplotlib)
  NETWORK RELATIONSHIPS (who connects to whom) →
    Need analytics (centrality, clustering)? → NetworkX + matplotlib
    Need interactivity in browser? → Plotly scatter (manual layout)
    Biological/molecular network? → Cytoscape.js (pyvis for Python)
    Large network (>10k nodes)? → Graph-tool or igraph
```

---

## 1. Plotly Sankey Diagram

Sankey diagrams show flows and transfers. Node width ∝ total flow through node. Link width ∝ flow volume.

### Complete Working Example (~100 lines)

```python
import plotly.graph_objects as go

# --- Data definition ---
# Nodes are referenced by index in the lists below
node_labels = [
    # Sources (left)
    "Solar",          # 0
    "Wind",           # 1
    "Natural Gas",    # 2
    "Coal",           # 3
    # Intermediaries (middle)
    "Electricity Grid",  # 4
    "Heat",              # 5
    # Consumers (right)
    "Residential",    # 6
    "Industrial",     # 7
    "Transport",      # 8
    "Losses",         # 9
]

node_colors = [
    "#f9c74f",  # Solar — yellow
    "#90be6d",  # Wind — green
    "#f8961e",  # Natural Gas — orange
    "#4d4d4d",  # Coal — dark gray
    "#577590",  # Electricity Grid — blue
    "#f94144",  # Heat — red
    "#43aa8b",  # Residential — teal
    "#277da1",  # Industrial — dark blue
    "#9b2226",  # Transport — crimson
    "#adb5bd",  # Losses — light gray
]

# source, target, value define directed edges
source = [0, 1, 2, 3, 2, 3, 4, 4, 4, 4, 5, 5]
target = [4, 4, 4, 4, 5, 5, 6, 7, 8, 9, 7, 6]
value  = [50, 80, 120, 60, 40, 30, 90, 100, 70, 50, 50, 20]

link_colors = [
    "rgba(249,199,79,0.4)",   # Solar → Grid
    "rgba(144,190,109,0.4)",  # Wind → Grid
    "rgba(248,150,30,0.4)",   # Gas → Grid
    "rgba(77,77,77,0.4)",     # Coal → Grid
    "rgba(248,150,30,0.3)",   # Gas → Heat
    "rgba(77,77,77,0.3)",     # Coal → Heat
    "rgba(87,117,144,0.4)",   # Grid → Residential
    "rgba(87,117,144,0.4)",   # Grid → Industrial
    "rgba(87,117,144,0.4)",   # Grid → Transport
    "rgba(173,181,189,0.3)",  # Grid → Losses
    "rgba(249,65,68,0.4)",    # Heat → Industrial
    "rgba(249,65,68,0.4)",    # Heat → Residential
]

fig = go.Figure(go.Sankey(
    arrangement="snap",   # "snap" | "fixed" | "perpendicular" | "freeform"
    node=dict(
        pad=20,           # vertical padding between nodes (pixels)
        thickness=20,     # node width (pixels)
        line=dict(color="black", width=0.5),
        label=node_labels,
        color=node_colors,
        hovertemplate="<b>%{label}</b><br>Total flow: %{value}<extra></extra>"
    ),
    link=dict(
        source=source,
        target=target,
        value=value,
        color=link_colors,
        hovertemplate=(
            "<b>%{source.label} → %{target.label}</b>"
            "<br>Flow: %{value} TWh<extra></extra>"
        )
    )
))

fig.update_layout(
    title=dict(text="Energy Flow Sankey", font_size=18),
    font_size=12,
    height=600,
    margin=dict(l=20, r=20, t=60, b=20)
)
fig.show()
# fig.write_html("sankey.html")
```

### Sankey Tips
- Sort nodes top-to-bottom by flow volume for readability
- Use semi-transparent link colors (rgba with ~0.4 alpha)
- `arrangement="snap"` lets users drag nodes; `"fixed"` locks positions
- For many small links, group into "Other" to reduce visual noise

---

## 2. Treemap — Proportional Hierarchy

Best when: area encoding of values matters; 2–4 levels of hierarchy; space-filling layout preferred.

```python
import plotly.express as px
import pandas as pd

# Hierarchical data with path notation
df = pd.DataFrame({
    "continent": ["Asia","Asia","Asia","Europe","Europe","Americas","Americas"],
    "country":   ["China","India","Japan","Germany","France","USA","Brazil"],
    "gdp":       [18000, 11000, 4900, 4500, 3100, 25000, 2100],
    "population":[1400, 1380, 125, 83, 67, 330, 214]
})

fig = px.treemap(
    df,
    path=[px.Constant("World"), "continent", "country"],  # hierarchy levels
    values="gdp",            # determines rectangle area
    color="population",      # color encoding (different from size)
    color_continuous_scale="RdYlGn",
    hover_data=["population"],
    title="GDP by Country (area) and Population (color)"
)
fig.update_traces(
    textinfo="label+value+percent parent",
    hovertemplate="<b>%{label}</b><br>GDP: $%{value}B<br>Pop: %{customdata[0]}M<extra></extra>"
)
fig.update_layout(margin=dict(t=50, l=0, r=0, b=0))
fig.show()
```

---

## 3. Sunburst — Radial Hierarchy

Best when: hierarchy depth is the focus; radial layout is more legible than nested rectangles; ≥3 levels.

```python
import plotly.express as px

fig = px.sunburst(
    df,
    path=["continent", "country"],
    values="gdp",
    color="gdp",
    color_continuous_scale="Blues",
    title="GDP Sunburst: Continent → Country"
)
fig.update_traces(
    insidetextorientation="radial",
    hovertemplate="<b>%{label}</b><br>GDP: $%{value}B<br>%{percentParent:.1%} of parent<extra></extra>"
)
fig.update_layout(margin=dict(t=50, l=0, r=0, b=0))
fig.show()
```

### Sunburst vs Treemap — When to Use

| Factor | Treemap | Sunburst |
|---|---|---|
| Levels | 2–3 levels optimal | 3–5 levels work well |
| Value encoding | Area is intuitive | Angle is less precise |
| Hierarchy focus | Secondary | Primary |
| Space efficiency | High | Moderate (corners wasted) |
| Click-to-zoom | Yes (px.treemap) | Yes (px.sunburst) |
| Colorblind risk | Lower (uses area) | Higher (uses angle+color) |

---

## 4. NetworkX + Matplotlib — Scientific Networks

For graph analytics, publication-quality network figures.

```python
import networkx as nx
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import numpy as np

# --- Build graph ---
G = nx.karate_club_graph()  # classic social network (34 nodes, 78 edges)

# --- Layout ---
# spring_layout = Fruchterman-Reingold force-directed
pos = nx.spring_layout(G, seed=42, k=0.8)  # k controls spacing
# Alternatives:
# pos = nx.circular_layout(G)
# pos = nx.spectral_layout(G)
# pos = nx.kamada_kawai_layout(G)  # better for small graphs, slower

# --- Graph analytics for visual encoding ---
degree = dict(G.degree())
betweenness = nx.betweenness_centrality(G)
communities = nx.community.greedy_modularity_communities(G)

# Map nodes to community colors
community_map = {}
for i, comm in enumerate(communities):
    for node in comm:
        community_map[node] = i

node_colors = [community_map[n] for n in G.nodes()]
node_sizes  = [300 + 1500 * betweenness[n] for n in G.nodes()]  # size by betweenness

# --- Plot ---
fig, ax = plt.subplots(figsize=(12, 10))

# Draw edges first (behind nodes)
nx.draw_networkx_edges(
    G, pos, ax=ax,
    alpha=0.3,
    width=0.8,
    edge_color="gray"
)

# Draw nodes
nodes = nx.draw_networkx_nodes(
    G, pos, ax=ax,
    node_color=node_colors,
    node_size=node_sizes,
    cmap=plt.cm.Set1,
    alpha=0.9
)

# Labels for high-degree nodes only
high_degree_nodes = {n: n for n, d in degree.items() if d >= 10}
nx.draw_networkx_labels(
    G, pos, labels=high_degree_nodes, ax=ax,
    font_size=9, font_weight="bold"
)

# Colorbar for communities
plt.colorbar(nodes, ax=ax, label="Community", shrink=0.6)

ax.set_title("Karate Club Network\nNode size = betweenness centrality, Color = community",
             fontsize=14, pad=20)
ax.axis("off")
plt.tight_layout()
plt.savefig("network.png", dpi=200, bbox_inches="tight")
plt.show()
```

### Graph Analytics Reference

```python
# Centrality measures
degree_centrality     = nx.degree_centrality(G)       # fraction of nodes connected to
betweenness_centrality = nx.betweenness_centrality(G)  # fraction of shortest paths through node
closeness_centrality  = nx.closeness_centrality(G)     # avg distance to all other nodes
eigenvector_centrality = nx.eigenvector_centrality(G)  # influence accounting for neighbor influence

# Clustering
clustering_coeff = nx.clustering(G)           # per-node: triangles / possible triangles
avg_clustering   = nx.average_clustering(G)   # global average
transitivity     = nx.transitivity(G)         # 3*triangles / triads

# Community detection
communities_greedy  = nx.community.greedy_modularity_communities(G)
communities_louvain = nx.community.louvain_communities(G, seed=42)  # NX 3.x
modularity = nx.community.modularity(G, communities_greedy)

# Path analytics
diameter = nx.diameter(G)                         # longest shortest path
avg_path = nx.average_shortest_path_length(G)     # small-world check

# Summary stats
print(f"Nodes: {G.number_of_nodes()}, Edges: {G.number_of_edges()}")
print(f"Density: {nx.density(G):.3f}")
print(f"Is connected: {nx.is_connected(G)}")
print(f"Components: {nx.number_connected_components(G)}")
```

---

## 5. Force-Directed Graph with Plotly (Interactive)

Manually extract layout from NetworkX and render with Plotly scatter traces.

```python
import plotly.graph_objects as go
import networkx as nx
import numpy as np

G = nx.karate_club_graph()
pos = nx.spring_layout(G, seed=42)

degree = dict(G.degree())
betweenness = nx.betweenness_centrality(G)

# --- Edge traces (one trace per edge for independent hover) ---
# Faster: single trace with None separators
edge_x, edge_y = [], []
for u, v in G.edges():
    x0, y0 = pos[u]
    x1, y1 = pos[v]
    edge_x += [x0, x1, None]
    edge_y += [y0, y1, None]

edge_trace = go.Scatter(
    x=edge_x, y=edge_y,
    mode="lines",
    line=dict(width=0.8, color="#aaaaaa"),
    hoverinfo="none",
    showlegend=False
)

# --- Node trace ---
node_x = [pos[n][0] for n in G.nodes()]
node_y = [pos[n][1] for n in G.nodes()]
node_sizes = [10 + 40 * betweenness[n] for n in G.nodes()]
node_text = [
    f"Node {n}<br>Degree: {degree[n]}<br>Betweenness: {betweenness[n]:.3f}"
    for n in G.nodes()
]

node_trace = go.Scatter(
    x=node_x, y=node_y,
    mode="markers",
    hoverinfo="text",
    hovertext=node_text,
    marker=dict(
        showscale=True,
        colorscale="Viridis",
        color=[betweenness[n] for n in G.nodes()],
        size=node_sizes,
        colorbar=dict(title="Betweenness", thickness=12),
        line=dict(width=1, color="white")
    )
)

fig = go.Figure(
    data=[edge_trace, node_trace],
    layout=go.Layout(
        title="Force-Directed Network (Plotly)",
        showlegend=False,
        hovermode="closest",
        xaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
        yaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
        margin=dict(l=0, r=0, t=40, b=0),
        height=600
    )
)
fig.show()
```

---

## 6. Dendrogram / Node-Link Hierarchy

For hierarchical clustering results or tree structures.

```python
import scipy.cluster.hierarchy as sch
import matplotlib.pyplot as plt
import numpy as np

# Generate sample data
np.random.seed(42)
data = np.random.randn(20, 4)
labels = [f"Sample {i}" for i in range(20)]

# Hierarchical clustering
linkage = sch.linkage(data, method="ward")

fig, ax = plt.subplots(figsize=(12, 5))
sch.dendrogram(
    linkage,
    labels=labels,
    ax=ax,
    color_threshold=3.0,       # color clusters above this distance
    leaf_rotation=45,
    leaf_font_size=10,
    above_threshold_color="gray"
)
ax.set_title("Hierarchical Clustering Dendrogram", fontsize=14)
ax.set_xlabel("Sample")
ax.set_ylabel("Distance (Ward)")
ax.axhline(y=3.0, color="r", linestyle="--", alpha=0.5, label="Cut threshold")
ax.legend()
plt.tight_layout()
plt.savefig("dendrogram.png", dpi=150, bbox_inches="tight")
plt.show()
```

---

## 7. Cytoscape.js / py4cytoscape — Biological Networks

For molecular, protein-protein interaction, or pathway networks where biological layout algorithms (e.g., Compound Spring Embedder) are standard.

```python
# pip install pyvis  — lightweight alternative for Python-embedded network viz
from pyvis.network import Network
import networkx as nx

G = nx.karate_club_graph()

net = Network(height="600px", width="100%", notebook=True, bgcolor="#222222", font_color="white")
net.from_nx(G)

# Physics options (force-directed)
net.set_options("""
var options = {
  "physics": {
    "forceAtlas2Based": {
      "gravitationalConstant": -50,
      "springLength": 100,
      "springConstant": 0.08
    },
    "solver": "forceAtlas2Based",
    "stabilization": {"iterations": 150}
  }
}
""")
net.show("network.html")
```

---

## 8. When to Use Each Approach

| Task | Tool | Why |
|---|---|---|
| Energy/money flows | Plotly Sankey | Width encodes volume naturally |
| File system hierarchy | Plotly Treemap | Area comparison at each level |
| Org chart / taxonomy | Plotly Sunburst | Depth is visually clear |
| Academic citation network | NetworkX + matplotlib | Analytics + publication output |
| Interactive relationship explorer | Plotly scatter + NetworkX | Browser interactivity |
| Biological pathway | Cytoscape.js / pyvis | Domain-specific layouts |
| Cluster visualization | Scipy dendrogram | Shows merge distances |
| Large graph (>10k nodes) | igraph / graph-tool + canvas | Performance |

---

## 9. Sankey Quick Customization Cheatsheet

```python
# Horizontal vs vertical
fig.update_traces(orientation="h")   # default horizontal
fig.update_traces(orientation="v")   # vertical Sankey

# Custom node positions (0–1 normalized)
fig = go.Figure(go.Sankey(
    node=dict(
        x=[0.1, 0.1, 0.5, 0.9, 0.9],  # manual x positions
        y=[0.2, 0.7, 0.5, 0.2, 0.7],  # manual y positions
        ...
    )
))

# Add units to hover
link=dict(
    ...,
    customdata=["GWh"] * len(source),
    hovertemplate="%{source.label} → %{target.label}<br>%{value} %{customdata}<extra></extra>"
)
```
