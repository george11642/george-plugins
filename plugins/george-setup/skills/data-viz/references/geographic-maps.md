# Geographic Maps Reference

Covers Plotly choropleth and scatter maps, Folium for GIS-style interactives, Mapbox integration, projection selection, color scale guidance, accessibility, and drill-down patterns.

---

## Decision Tree

```
Geographic data type?
  REGIONS (countries, states, counties) + numeric value →
    Need tile basemap (streets, satellite)?
      YES → px.choropleth_map (formerly choropleth_mapbox)
      NO  → px.choropleth with scope/projection
  POINT DATA (lat/lon coordinates) →
    Need tile basemap?
      YES → px.scatter_map (formerly scatter_mapbox)
      NO  → go.Scattergeo
  COMPLEX GIS (markers, popups, layers, heatmaps) → Folium
  CUSTOM TILES (terrain, satellite, custom styles) → Mapbox token + go.Choroplethmapbox
```

---

## 1. px.choropleth — Outline-Based Choropleth

Best for: country/state/region comparisons without a tile basemap. No API key needed.

```python
import plotly.express as px
import pandas as pd

# Built-in world data example
df = px.data.gapminder().query("year == 2007")

fig = px.choropleth(
    df,
    locations="iso_alpha",           # ISO 3-letter country codes
    color="lifeExp",
    hover_name="country",
    color_continuous_scale="Viridis",
    range_color=(40, 85),
    labels={"lifeExp": "Life Expectancy"},
    title="Global Life Expectancy (2007)"
)
fig.update_layout(
    geo=dict(
        showframe=False,
        showcoastlines=True,
        projection_type="natural earth"  # see projection section below
    ),
    coloraxis_colorbar=dict(
        title="Years",
        thicknessmode="pixels", thickness=15,
        lenmode="fraction", len=0.5,
        yanchor="middle", y=0.5
    ),
    margin={"r": 0, "t": 40, "l": 0, "b": 0}
)
fig.show()
```

### Custom GeoJSON Regions

Use when you need sub-national regions (counties, postal codes, custom districts).

```python
import plotly.express as px
import pandas as pd
import json
from urllib.request import urlopen

# Load GeoJSON — key rule: features must have an 'id' field OR use featureidkey
with urlopen('https://raw.githubusercontent.com/plotly/datasets/master/geojson-counties-fips.json') as r:
    counties = json.load(r)

df = pd.read_csv(
    "https://raw.githubusercontent.com/plotly/datasets/master/fips-unemp-16.csv",
    dtype={"fips": str}  # keep leading zeros
)

fig = px.choropleth(
    df,
    geojson=counties,
    locations="fips",               # column in df matching GeoJSON feature ids
    color="unemp",
    scope="usa",
    color_continuous_scale="YlOrRd",
    range_color=(0, 12),
    labels={"unemp": "Unemployment %"},
    title="US Unemployment by County (2016)"
)
fig.update_geos(fitbounds="locations", visible=False)
fig.update_layout(margin={"r": 0, "t": 40, "l": 0, "b": 0})
fig.show()
```

**featureidkey** — when GeoJSON id is nested in properties:
```python
# GeoJSON has: {"properties": {"NAME": "California"}}
fig = px.choropleth(
    df,
    geojson=geojson_data,
    featureidkey="properties.NAME",  # path into each feature object
    locations="state_name",          # df column matching that path
    color="value"
)
```

---

## 2. px.choropleth_map — Tile-Based Choropleth

Replaces the deprecated `px.choropleth_mapbox`. Renders on an interactive tile map.

```python
import plotly.express as px
import pandas as pd
import json
from urllib.request import urlopen

with urlopen('https://raw.githubusercontent.com/plotly/datasets/master/geojson-counties-fips.json') as r:
    counties = json.load(r)

df = pd.read_csv(
    "https://raw.githubusercontent.com/plotly/datasets/master/fips-unemp-16.csv",
    dtype={"fips": str}
)

fig = px.choropleth_map(
    df,
    geojson=counties,
    locations="fips",
    color="unemp",
    color_continuous_scale="Viridis",
    range_color=(0, 12),
    map_style="carto-positron",     # free tile style, no token needed
    zoom=3,
    center={"lat": 37.09, "lon": -95.71},
    opacity=0.5,
    labels={"unemp": "Unemployment %"}
)
fig.update_layout(margin={"r": 0, "t": 0, "l": 0, "b": 0})
fig.show()
```

**Free tile styles** (no Mapbox token): `"carto-positron"`, `"carto-darkmatter"`, `"open-street-map"`, `"stamen-terrain"`, `"stamen-watercolor"`

---

## 3. px.scatter_map — Point Data on Tiles

For lat/lon point data with size/color encoding.

```python
import plotly.express as px
import pandas as pd

# Example: earthquake data
df = px.data.carshare()  # substitute your lat/lon dataframe

fig = px.scatter_map(
    df,
    lat="centroid_lat",
    lon="centroid_lon",
    color="peak_hour",
    size="car_hours",
    color_continuous_scale=px.colors.sequential.Plasma,
    size_max=15,
    zoom=10,
    map_style="carto-positron",
    hover_name="peak_hour",
    title="Car Share Usage by Location"
)
fig.update_layout(margin={"r": 0, "t": 40, "l": 0, "b": 0})
fig.show()
```

---

## 4. go.Scattergeo — Point Data Without Tiles

No API key. Good for publication-style maps.

```python
import plotly.graph_objects as go
import pandas as pd

df = pd.read_csv(
    'https://raw.githubusercontent.com/plotly/datasets/master/2011_february_us_airport_traffic.csv'
)
df['text'] = df['airport'] + ' — ' + df['city'] + ', ' + df['state']

fig = go.Figure(go.Scattergeo(
    locationmode='USA-states',
    lon=df['long'],
    lat=df['lat'],
    text=df['text'],
    mode='markers',
    marker=dict(
        size=df['cnt'] / df['cnt'].max() * 20 + 3,  # scale by traffic
        color=df['cnt'],
        colorscale='Blues',
        showscale=True,
        colorbar_title="Arrivals",
        opacity=0.8,
        line=dict(width=0.5, color='rgba(100,100,100,0.5)')
    )
))
fig.update_layout(
    title='US Airport Traffic — February 2011',
    geo=dict(
        scope='usa',
        projection_type='albers usa',
        showland=True,
        landcolor='rgb(245,245,245)',
        subunitcolor='rgb(200,200,200)',
        countrycolor='rgb(200,200,200)'
    ),
    margin={"r": 0, "t": 40, "l": 0, "b": 0}
)
fig.show()
```

---

## 5. Folium — GIS-Style Interactive Maps

Best for: layers, popups with HTML content, heatmaps, marker clusters, tile switching. Output is a self-contained HTML file.

```python
# pip install folium
import folium
from folium.plugins import HeatMap, MarkerCluster
import pandas as pd

# Base map
m = folium.Map(
    location=[37.09, -95.71],
    zoom_start=4,
    tiles="CartoDB positron"     # tile options: OpenStreetMap, CartoDB dark_matter, Stamen Terrain
)

# --- Simple marker with popup ---
folium.Marker(
    location=[40.7128, -74.0060],
    popup=folium.Popup("<b>New York City</b><br>Population: 8.3M", max_width=200),
    tooltip="Click for info",
    icon=folium.Icon(color="blue", icon="info-sign")
).add_to(m)

# --- CircleMarker for point data (faster than Marker for large datasets) ---
data_points = [(40.71, -74.01), (34.05, -118.24), (41.88, -87.63)]
for lat, lon in data_points:
    folium.CircleMarker(
        location=[lat, lon],
        radius=8,
        color="#e74c3c",
        fill=True,
        fill_opacity=0.7,
        popup=f"({lat:.2f}, {lon:.2f})"
    ).add_to(m)

# --- Heatmap layer ---
heat_data = [[row['lat'], row['lon'], row['weight']]
             for _, row in df.iterrows()]
HeatMap(
    heat_data,
    radius=15,
    blur=10,
    max_zoom=13,
    gradient={0.2: 'blue', 0.5: 'lime', 1.0: 'red'}
).add_to(m)

# --- Marker cluster for dense point sets ---
cluster = MarkerCluster().add_to(m)
for _, row in df.iterrows():
    folium.Marker(
        location=[row['lat'], row['lon']],
        popup=row['name']
    ).add_to(cluster)

# --- Choropleth layer from GeoJSON + data ---
folium.Choropleth(
    geo_data='states.geojson',
    data=df,
    columns=['state', 'value'],
    key_on='feature.properties.name',
    fill_color='YlOrRd',
    fill_opacity=0.7,
    line_opacity=0.2,
    legend_name='Value',
    nan_fill_color='lightgray'
).add_to(m)

# Layer control (toggle layers on/off)
folium.LayerControl().add_to(m)

m.save('map.html')
# In Jupyter: display(m)
```

---

## 6. Mapbox Integration

Requires a free Mapbox token from mapbox.com.

```python
import plotly.graph_objects as go
import json
from urllib.request import urlopen
import pandas as pd

token = open(".mapbox_token").read().strip()

with urlopen('https://raw.githubusercontent.com/plotly/datasets/master/geojson-counties-fips.json') as r:
    counties = json.load(r)

df = pd.read_csv(
    "https://raw.githubusercontent.com/plotly/datasets/master/fips-unemp-16.csv",
    dtype={"fips": str}
)

fig = go.Figure(go.Choroplethmapbox(
    geojson=counties,
    locations=df['fips'],
    z=df['unemp'],
    colorscale="Viridis",
    zmin=0, zmax=12,
    marker_opacity=0.5,
    marker_line_width=0,
    colorbar_title="Unemployment %"
))
fig.update_layout(
    mapbox_style="mapbox://styles/mapbox/light-v11",  # Mapbox style URL
    mapbox_accesstoken=token,
    mapbox_zoom=3,
    mapbox_center={"lat": 37.09, "lon": -95.71},
    margin={"r": 0, "t": 0, "l": 0, "b": 0}
)
fig.show()
```

---

## 7. Projection Selection

Used with `go.layout.Geo` (outline maps only, not tile maps).

| Projection | Use Case |
|---|---|
| `"natural earth"` | General world maps, aesthetically pleasing default |
| `"equirectangular"` | Simple lat/lon grid, good for data analysis |
| `"mercator"` | Navigation, web maps; distorts polar regions |
| `"orthographic"` | Globe view, single hemisphere |
| `"albers usa"` | US-specific, includes Alaska + Hawaii insets |
| `"kavrayskiy7"` | Low distortion world maps |
| `"robinson"` | UN-style balanced distortion world maps |

```python
fig.update_layout(
    geo=dict(
        projection_type="natural earth",
        showocean=True,
        oceancolor="LightBlue",
        showland=True,
        landcolor="LightYellow",
        showlakes=True,
        lakecolor="LightBlue",
        showrivers=True,
        rivercolor="Blue",
        showcountries=True,
        countrycolor="Gray"
    )
)
```

---

## 8. Color Scale Selection for Geographic Data

**Sequential** (one direction: low to high):
- `"Viridis"` — colorblind-safe default, perceptually uniform
- `"YlOrRd"` — yellow → orange → red, intuitive for intensity
- `"Blues"` / `"Greens"` — single-hue, clean
- `"Plasma"` — high contrast, good on dark backgrounds

**Diverging** (two directions from a midpoint):
- `"RdBu"` — red/blue for positive/negative (e.g., temperature anomalies)
- `"PiYG"` — pink/green for gain/loss
- `"BrBG"` — brown/blue-green for drought/wet

```python
# Diverging with explicit midpoint
fig = px.choropleth(
    df, locations="iso_alpha", color="change",
    color_continuous_scale="RdBu",
    color_continuous_midpoint=0,   # center the diverging scale at zero
    range_color=(-20, 20)
)
```

**Rules of thumb**:
- Never use `jet` or `rainbow` — creates false boundaries and fails colorblindness
- Use diverging only when 0 (or another midpoint) is meaningful
- For log-scale data: apply `np.log10(df['value'])` before mapping to color

---

## 9. Map Accessibility

```python
# Colorblind-safe palette for choropleth
fig = px.choropleth(
    df, locations="iso_alpha", color="value",
    color_continuous_scale="cividis"   # perceptually uniform, blue-yellow
)

# Add legend title and position
fig.update_layout(
    coloraxis_colorbar=dict(
        title=dict(text="Value", side="right"),
        x=1.02,
        xanchor="left"
    )
)

# Add aria label for web embedding
fig.update_layout(
    meta={"description": "Choropleth map showing value by country. Darker blue indicates higher values."}
)
```

**Checklist**:
- Use perceptually uniform scales (Viridis, Cividis, Plasma) — avoid Jet/Rainbow
- Label the colorbar with units
- Include a data table or CSV download alongside any web map
- Do not rely solely on color — add hover text with numeric values
- Minimum 3:1 contrast between region colors and boundary lines

---

## 10. Drill-Down Pattern: Country → State → City

```python
import plotly.express as px
import pandas as pd
from dash import Dash, dcc, html, Input, Output

app = Dash(__name__)

country_data = pd.DataFrame({
    "iso_alpha": ["USA", "CAN", "MEX"],
    "value": [85, 72, 61],
    "country": ["United States", "Canada", "Mexico"]
})

state_data = {
    "USA": pd.DataFrame({
        "state": ["CA", "TX", "NY", "FL"],
        "value": [90, 78, 88, 82],
        "lat": [36.7, 31.9, 42.3, 27.7],
        "lon": [-119.4, -99.9, -74.0, -81.5]
    }),
    # Add other countries...
}

app.layout = html.Div([
    html.H3("Click a country to drill down"),
    dcc.Graph(id="world-map"),
    dcc.Graph(id="state-map"),
    html.Div(id="selected-country", style={"display": "none"})
])

@app.callback(
    Output("world-map", "figure"),
    Input("world-map", "id")  # fires on load
)
def draw_world(_):
    return px.choropleth(
        country_data,
        locations="iso_alpha",
        color="value",
        hover_name="country",
        color_continuous_scale="Viridis",
        title="Click a country to drill down"
    )

@app.callback(
    Output("state-map", "figure"),
    Input("world-map", "clickData")
)
def drill_down(click_data):
    if not click_data:
        return px.scatter(title="Select a country above")

    country_code = click_data["points"][0]["location"]
    if country_code not in state_data:
        return px.scatter(title=f"No state data for {country_code}")

    df = state_data[country_code]
    return px.scatter_geo(
        df,
        lat="lat", lon="lon",
        color="value",
        hover_name="state",
        size="value",
        scope="usa" if country_code == "USA" else "world",
        title=f"States in {country_code}"
    )

if __name__ == "__main__":
    app.run_server(debug=True)
```

---

## Quick Reference

| Tool | API Key | Tile Map | GeoJSON | Best For |
|---|---|---|---|---|
| `px.choropleth` | No | No | Yes | Publication maps, country/state |
| `px.choropleth_map` | No (free tiles) | Yes | Yes | Interactive web maps |
| `go.Choroplethmapbox` | Mapbox | Yes | Yes | Custom Mapbox styles |
| `go.Scattergeo` | No | No | No | Point data, publication |
| `px.scatter_map` | No (free tiles) | Yes | No | Point data, interactive |
| Folium | No | Yes | Yes | GIS layers, markers, clusters |
