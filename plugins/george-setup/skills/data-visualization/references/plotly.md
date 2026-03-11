# Plotly Reference

Interactive Python graphing library with 40+ chart types.

## Installation
```bash
uv pip install plotly
uv pip install kaleido  # For static image export
uv pip install dash     # For web app dashboards
```

## API Choice

### Plotly Express (px) - High-level
```python
import plotly.express as px
fig = px.scatter(df, x='x', y='y', color='group', title='My Plot')
fig.show()
```
Best for: DataFrames, standard charts, auto legends/colors, minimal code.

### Graph Objects (go) - Low-level
```python
import plotly.graph_objects as go
fig = go.Figure(data=[go.Scatter(x=[1,2,3], y=[4,5,6])])
fig.update_layout(title='Custom')
```
Best for: Custom multi-trace figures, chart types not in px, precise control.

### Combining Both
```python
fig = px.scatter(df, x='x', y='y')
fig.update_layout(title='Custom Title')
fig.add_hline(y=10)
```

## Chart Types

### Basic
```python
px.scatter(df, x='x', y='y')
px.line(df, x='date', y='value')
px.bar(df, x='category', y='count')
px.pie(df, values='amount', names='label')
px.area(df, x='date', y='value')
```

### Statistical
```python
px.histogram(df, x='values', color='group', marginal='box', nbins=30)
px.box(df, x='category', y='value', points='all')
px.violin(df, x='group', y='measurement', box=True)
px.scatter(df, x='x', y='y', trendline='ols')
```

### Scientific
```python
px.imshow(matrix, text_auto=True, color_continuous_scale='RdBu')
go.Figure(data=[go.Surface(z=z_data, x=x_data, y=y_data)])
```

### Financial
```python
px.line(df, x='date', y='price')
fig.update_xaxes(rangeslider_visible=True)

go.Figure(data=[go.Candlestick(
    x=df['date'], open=df['open'], high=df['high'],
    low=df['low'], close=df['close']
)])
```

### Maps
```python
px.choropleth(df, locations='country', color='value')
px.scatter_map(df, lat='lat', lon='lon', size='pop')
```

### 3D
```python
px.scatter_3d(df, x='x', y='y', z='z', color='group')
go.Figure(data=[go.Surface(z=z_data)])
```

### Specialized
```python
px.sunburst(df, path=['continent', 'country'], values='pop')
px.treemap(df, path=['sector', 'company'], values='revenue')
go.Figure(data=[go.Sankey(node=..., link=...)])
px.parallel_coordinates(df, dimensions=['a', 'b', 'c'])
```

## Subplots
```python
from plotly.subplots import make_subplots
fig = make_subplots(
    rows=2, cols=2,
    subplot_titles=('A', 'B', 'C', 'D'),
    specs=[[{'type': 'scatter'}, {'type': 'bar'}],
           [{'type': 'histogram'}, {'type': 'box'}]]
)
fig.add_trace(go.Scatter(x=[1,2], y=[3,4]), row=1, col=1)
fig.update_layout(height=800, showlegend=False)
```

## Templates
```python
fig = px.scatter(df, x='x', y='y', template='plotly_dark')
# Built-in: plotly_white, plotly_dark, ggplot2, seaborn, simple_white
```

## Interactivity
```python
# Custom hover
fig.update_traces(
    hovertemplate='<b>%{x}</b><br>Value: %{y:.2f}<extra></extra>'
)
# Range slider
fig.update_xaxes(rangeslider_visible=True)
# Animation
fig = px.scatter(df, x='x', y='y', animation_frame='year')
```

## Export
```python
fig.write_html('chart.html')                          # Full standalone
fig.write_html('chart.html', include_plotlyjs='cdn')   # Smaller file
fig.write_image('chart.png')                           # PNG (needs kaleido)
fig.write_image('chart.pdf')                           # PDF
fig.write_image('chart.svg')                           # SVG
```

## Dash Integration
```python
import dash
from dash import dcc, html

app = dash.Dash(__name__)
fig = px.scatter(df, x='x', y='y')
app.layout = html.Div([
    html.H1('Dashboard'),
    dcc.Graph(figure=fig)
])
app.run_server(debug=True)
```
