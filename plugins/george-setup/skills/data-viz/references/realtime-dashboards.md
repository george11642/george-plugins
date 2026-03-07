# Real-Time Dashboards Reference

Covers Plotly Dash live updates (dcc.Interval), streaming strategies, circular buffers, alert styling, Bento grid layouts, caching, and Bokeh server as an alternative.

---

## Architecture Decision

```
How often does data change?
  Every 1–30 seconds AND < 1000 concurrent users → dcc.Interval polling (simplest)
  Sub-second latency needed OR > 1000 concurrent users → WebSocket (Dash + Flask-SocketIO)
  Computation is heavy (ML inference, DB aggregation) → Add diskcache/Redis layer
  Need horizontal scaling → Celery + Redis backend
  Very high throughput (100k+ points/sec) → Bokeh server with websocket push
```

**Rule of thumb**: Start with polling. Move to WebSocket only when 250ms polling lag is visibly problematic.

---

## 1. dcc.Interval — Core Live Update Pattern

`dcc.Interval` fires a callback on a timer. The callback fetches new data and returns an updated figure.

```python
from dash import Dash, dcc, html, Input, Output
import plotly.graph_objects as go
import pandas as pd
from datetime import datetime
import random

app = Dash(__name__)

app.layout = html.Div([
    html.H2("Live System Monitor"),
    dcc.Interval(
        id="interval",
        interval=2000,    # milliseconds between callbacks (2 seconds)
        n_intervals=0     # counter, increments each tick
    ),
    dcc.Graph(id="live-chart"),
    html.Div(id="status-badge")
])

# Simulated data source — replace with real DB/API call
_history = {"time": [], "cpu": [], "mem": []}

@app.callback(
    Output("live-chart", "figure"),
    Output("status-badge", "children"),
    Input("interval", "n_intervals")
)
def update_chart(n):
    # Append new data point
    _history["time"].append(datetime.now().strftime("%H:%M:%S"))
    _history["cpu"].append(random.uniform(10, 90))
    _history["mem"].append(random.uniform(40, 80))

    # Keep last 60 points
    for key in _history:
        _history[key] = _history[key][-60:]

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=_history["time"], y=_history["cpu"],
        name="CPU %", mode="lines",
        line=dict(color="#e74c3c", width=2)
    ))
    fig.add_trace(go.Scatter(
        x=_history["time"], y=_history["mem"],
        name="Memory %", mode="lines",
        line=dict(color="#3498db", width=2)
    ))

    fig.update_layout(
        xaxis_title="Time",
        yaxis_title="Utilization %",
        yaxis=dict(range=[0, 100]),
        legend=dict(orientation="h", y=1.1),
        margin=dict(l=40, r=20, t=20, b=40),
        template="plotly_dark",
        height=350,
        uirevision="constant"  # CRITICAL: prevents zoom reset on each update
    )

    cpu_now = _history["cpu"][-1]
    color = "#e74c3c" if cpu_now > 80 else "#f39c12" if cpu_now > 60 else "#2ecc71"
    badge = html.Span(
        f"CPU: {cpu_now:.0f}%",
        style={"background": color, "color": "white", "padding": "4px 12px",
               "borderRadius": "12px", "fontWeight": "bold"}
    )
    return fig, badge

if __name__ == "__main__":
    app.run_server(debug=True)
```

**Key detail**: `uirevision="constant"` on the layout prevents Plotly from resetting zoom/pan state on every callback update.

---

## 2. extendData — Streaming Without Full Redraw

`extendData` appends points to existing traces without regenerating the entire figure. Much faster for high-frequency updates.

```python
from dash import Dash, dcc, html, Input, Output
import plotly.graph_objects as go
import random
from datetime import datetime

app = Dash(__name__)

# Initial figure with empty traces
initial_fig = go.Figure(
    data=[
        go.Scatter(x=[], y=[], mode="lines", name="Sensor A", line=dict(color="#e74c3c")),
        go.Scatter(x=[], y=[], mode="lines", name="Sensor B", line=dict(color="#3498db")),
    ],
    layout=go.Layout(
        xaxis=dict(type="date", range=[None, None]),
        yaxis=dict(range=[-5, 5]),
        template="plotly_dark",
        height=400,
        uirevision="constant"
    )
)

app.layout = html.Div([
    dcc.Graph(id="stream-chart", figure=initial_fig),
    dcc.Interval(id="stream-interval", interval=100, n_intervals=0),  # 100ms = 10 Hz
    dcc.Store(id="n-points", data=0)
])

@app.callback(
    Output("stream-chart", "extendData"),
    Output("n-points", "data"),
    Input("stream-interval", "n_intervals"),
    prevent_initial_call=True
)
def stream_data(n):
    t = datetime.now().isoformat()

    # extendData format: (dict of trace updates, trace indices, max points to keep)
    new_data = dict(
        x=[[t], [t]],                          # one list per trace
        y=[[random.gauss(0, 1)],               # trace 0 data
           [random.gauss(0, 0.5)]]             # trace 1 data
    )
    trace_indices = [0, 1]   # which traces to extend
    max_points = 200         # rolling window — older points dropped automatically

    return (new_data, trace_indices, max_points), n + 1
```

**extendData vs replaceData**:
- `extendData`: append new points, keep old ones (up to `max_points`). Use for streaming.
- `figure` update: replace entire figure. Use for refresh (new query results).
- Mix them: use `extendData` for the chart, separate `figure` update for summary stats panel.

---

## 3. Circular Buffer for Live Time-Series

Use Python's `collections.deque` with `maxlen` for O(1) append/drop.

```python
from collections import deque
import threading
import time
import random

# Thread-safe circular buffer
class LiveBuffer:
    def __init__(self, maxlen=500):
        self.times = deque(maxlen=maxlen)
        self.values = deque(maxlen=maxlen)
        self._lock = threading.Lock()

    def append(self, t, v):
        with self._lock:
            self.times.append(t)
            self.values.append(v)

    def snapshot(self):
        """Return list copies for safe iteration outside lock."""
        with self._lock:
            return list(self.times), list(self.values)

buffer = LiveBuffer(maxlen=300)

# Background thread simulating hardware sensor
def sensor_thread():
    while True:
        buffer.append(time.time(), random.gauss(0, 1))
        time.sleep(0.05)  # 20 Hz sensor

import threading
t = threading.Thread(target=sensor_thread, daemon=True)
t.start()

# In Dash callback:
# times, values = buffer.snapshot()
# fig.update_traces(x=times, y=values)
```

---

## 4. Complete Live Dashboard Example (~80 lines)

```python
from dash import Dash, dcc, html, Input, Output, State
import dash_bootstrap_components as dbc
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from collections import deque
import random, time

app = Dash(__name__, external_stylesheets=[dbc.themes.DARKLY])

N = 120  # 2 minutes at 1Hz
t_buf   = deque(maxlen=N)
cpu_buf = deque(maxlen=N)
mem_buf = deque(maxlen=N)
req_buf = deque(maxlen=N)

def fetch_metrics():
    """Replace with real monitoring API call."""
    return {
        "cpu": random.uniform(20, 95),
        "mem": random.uniform(45, 85),
        "req_per_sec": random.randint(100, 500)
    }

app.layout = dbc.Container([
    dbc.Row([
        dbc.Col(html.H3("System Dashboard", className="text-white"), width=8),
        dbc.Col(
            dbc.Switch(id="pause-switch", label="Pause", value=False),
            width=4, className="text-end pt-2"
        )
    ], className="mb-3"),

    # KPI cards row
    dbc.Row([
        dbc.Col(dbc.Card(dbc.CardBody([
            html.H6("CPU", className="text-muted"),
            html.H3(id="kpi-cpu", className="mb-0")
        ])), width=4),
        dbc.Col(dbc.Card(dbc.CardBody([
            html.H6("Memory", className="text-muted"),
            html.H3(id="kpi-mem", className="mb-0")
        ])), width=4),
        dbc.Col(dbc.Card(dbc.CardBody([
            html.H6("Req/sec", className="text-muted"),
            html.H3(id="kpi-req", className="mb-0")
        ])), width=4),
    ], className="mb-3"),

    dbc.Row([
        dbc.Col(dcc.Graph(id="main-chart"), width=12)
    ]),

    dcc.Interval(id="tick", interval=1000, n_intervals=0),
    dcc.Loading(id="loading", children=html.Div(id="loading-placeholder"), type="circle")
], fluid=True)

@app.callback(
    Output("main-chart", "figure"),
    Output("kpi-cpu", "children"),
    Output("kpi-cpu", "style"),
    Output("kpi-mem", "children"),
    Output("kpi-req", "children"),
    Input("tick", "n_intervals"),
    State("pause-switch", "value"),
    prevent_initial_call=True
)
def tick(n, paused):
    if not paused:
        m = fetch_metrics()
        t_buf.append(n)
        cpu_buf.append(m["cpu"])
        mem_buf.append(m["mem"])
        req_buf.append(m["req_per_sec"])

    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        subplot_titles=("CPU & Memory %", "Requests/sec"))

    fig.add_trace(go.Scatter(x=list(t_buf), y=list(cpu_buf),
        name="CPU", line=dict(color="#e74c3c")), row=1, col=1)
    fig.add_trace(go.Scatter(x=list(t_buf), y=list(mem_buf),
        name="Mem", line=dict(color="#3498db")), row=1, col=1)
    fig.add_trace(go.Bar(x=list(t_buf), y=list(req_buf),
        name="Req/s", marker_color="#2ecc71"), row=2, col=1)

    fig.update_layout(height=500, template="plotly_dark", uirevision="constant",
                      margin=dict(l=40, r=20, t=40, b=20))
    fig.update_yaxes(range=[0, 100], row=1)

    cpu = cpu_buf[-1] if cpu_buf else 0
    cpu_color = {"color": "#e74c3c"} if cpu > 80 else {"color": "#f39c12"} if cpu > 60 else {"color": "#2ecc71"}

    return (fig,
            f"{cpu:.0f}%", cpu_color,
            f"{mem_buf[-1]:.0f}%" if mem_buf else "—",
            f"{req_buf[-1]}" if req_buf else "—")

if __name__ == "__main__":
    app.run_server(debug=True)
```

---

## 5. WebSocket vs Polling Trade-Offs

| Factor | Polling (dcc.Interval) | WebSocket |
|---|---|---|
| Setup complexity | Minimal | Moderate (Flask-SocketIO) |
| Latency | = interval period (100ms–30s) | < 10ms |
| Server load | Scales with interval × users | Lower per-message overhead |
| Firewalls/proxies | Always works | May need WS support |
| Data push | Pull (client asks) | Push (server sends) |
| Recommended for | < 200 concurrent, > 250ms refresh | High-frequency, many users |

For WebSocket in Dash:
```python
# pip install flask-socketio dash-extensions
from dash_extensions.enrich import DashProxy
from dash_extensions import WebSocket
# Then use WebSocket component + server-side emit
```

---

## 6. Alert Styling — Color Thresholds

```python
def threshold_color(value, warn=70, crit=90):
    """Return Bootstrap color class based on thresholds."""
    if value >= crit:
        return "danger"    # red
    elif value >= warn:
        return "warning"   # yellow/orange
    else:
        return "success"   # green

# In layout:
dbc.Alert(f"CPU: {cpu:.0f}%", color=threshold_color(cpu), className="py-1 mb-0")

# Conditional row highlight in DataTable:
style_data_conditional = [
    {"if": {"filter_query": "{cpu} > 90"}, "backgroundColor": "#ff4444", "color": "white"},
    {"if": {"filter_query": "{cpu} > 70 && {cpu} <= 90"}, "backgroundColor": "#ff8800"},
]
```

---

## 7. Caching Heavy Computations

```python
# pip install diskcache
import diskcache
from dash import DiskcacheManager

cache = diskcache.Cache("./cache_dir")
background_callback_manager = DiskcacheManager(cache)

# Use for callbacks that take > 1 second
@app.callback(
    Output("expensive-chart", "figure"),
    Input("run-button", "n_clicks"),
    background=True,              # runs in background thread
    manager=background_callback_manager,
    running=[
        (Output("run-button", "disabled"), True, False),
        (Output("loading-indicator", "style"), {"display": "block"}, {"display": "none"})
    ],
    cache_args_to_ignore=[0]      # don't cache based on n_clicks
)
def expensive_computation(n_clicks):
    time.sleep(3)  # simulate heavy work
    return px.scatter(px.data.iris(), x="sepal_width", y="sepal_length")

# Redis for production multi-worker:
# pip install celery redis
# from dash import CeleryManager
# from celery import Celery
# celery_app = Celery(__name__, broker="redis://localhost:6379/0")
# manager = CeleryManager(celery_app)
```

---

## 8. Bokeh Server — Alternative for Scale

Bokeh uses a true WebSocket push model — server pushes to clients rather than polling.

```python
# pip install bokeh
from bokeh.plotting import figure, curdoc
from bokeh.models import ColumnDataSource
from bokeh.layouts import column
import random
from functools import partial

source = ColumnDataSource({"x": [], "y": []})

p = figure(title="Live Stream", x_axis_type="datetime",
           height=300, width=700)
p.line("x", "y", source=source, line_width=2, color="#e74c3c")

def update():
    import datetime
    new_data = {
        "x": [datetime.datetime.now()],
        "y": [random.gauss(0, 1)]
    }
    source.stream(new_data, rollover=300)  # rollover = max points

curdoc().add_root(column(p))
curdoc().add_periodic_callback(update, 500)  # 500ms interval
# Run: bokeh serve --show script.py
```

---

## 9. dcc.Loading — Spinner States

```python
app.layout = html.Div([
    # Wrap any component that may take time to update
    dcc.Loading(
        id="loading-wrapper",
        type="circle",      # "circle" | "dot" | "default" | "cube"
        color="#3498db",
        children=dcc.Graph(id="slow-chart")
    )
])
# The spinner shows automatically while callback is running
```
