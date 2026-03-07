# Observability

Observability answers the question: "What is my system doing right now?" — without requiring you to predict failures in advance. The goal is not just monitoring but understanding system behavior from external outputs.

## The Four Pillars

| Pillar | Tool (OSS) | Tool (Commercial) | Purpose |
|--------|------------|-------------------|---------|
| Metrics | Prometheus | Datadog, New Relic | Numeric time-series, aggregated stats |
| Logs | Loki, ELK Stack | Datadog Logs | Event records, debug output |
| Traces | Jaeger, Tempo | Datadog APM, New Relic | Request path across services |
| Profiles | Pyroscope, Parca | Datadog Continuous Profiler | CPU/memory hotspots over time |

Rule of thumb: metrics tell you *something is wrong*, logs tell you *what happened*, traces tell you *where it happened*, profiles tell you *why it's slow*.

---

## Prometheus + Grafana Stack

### prometheus.yml Scrape Config

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'prod-us-east-1'
    env: 'production'

rule_files:
  - /etc/prometheus/rules/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Only scrape pods with annotation prometheus.io/scrape: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
```

### ServiceMonitor CRD (Prometheus Operator)

Instead of editing prometheus.yml, Prometheus Operator watches ServiceMonitor CRDs. Operators running in the cluster auto-discover them.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
  labels:
    app: my-app
spec:
  selector:
    matchLabels:
      app: my-app         # Must match the Service's labels
  namespaceSelector:
    matchNames:
      - default
      - production
  endpoints:
    - port: metrics        # Port name on the Service
      interval: 30s
      path: /metrics
      scheme: http
      # Optional TLS if metrics endpoint is HTTPS
      # tlsConfig:
      #   insecureSkipVerify: true
```

### Recording Rules (pre-compute expensive queries)

```yaml
# /etc/prometheus/rules/recording_rules.yml
groups:
  - name: http_request_rates
    interval: 30s
    rules:
      # Pre-compute per-service request rate (5m window)
      - record: job:http_requests_total:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      # Pre-compute error ratio per job
      - record: job:http_request_errors:ratio5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum by (job) (rate(http_requests_total[5m]))
```

### Alert Rules

```yaml
# /etc/prometheus/rules/alert_rules.yml
groups:
  - name: slo-alerts
    rules:
      - alert: HighErrorRate
        expr: job:http_request_errors:ratio5m > 0.05
        for: 5m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High error rate on {{ $labels.job }}"
          description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.job }}"
          runbook_url: "https://wiki.example.com/runbooks/high-error-rate"

      - alert: HighLatency
        expr: histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (job, le)) > 2.0
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "P99 latency > 2s on {{ $labels.job }}"
```

### Grafana Dashboard Provisioning

Grafana can auto-load dashboards from ConfigMaps or mounted files. No manual import needed.

```yaml
# grafana-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"   # Grafana sidecar watches for this label
data:
  my-app.json: |
    {
      "title": "My App",
      "uid": "my-app-overview",
      "panels": [
        {
          "title": "Request Rate",
          "type": "graph",
          "targets": [
            {
              "expr": "job:http_requests_total:rate5m{job=\"my-app\"}",
              "legendFormat": "req/s"
            }
          ]
        }
      ]
    }
```

### Alertmanager Routing

```yaml
# alertmanager.yml
global:
  slack_api_url: 'https://hooks.slack.com/services/...'
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

route:
  group_by: ['alertname', 'job']
  group_wait: 30s        # Wait before sending first notification
  group_interval: 5m     # Wait before sending new group notification
  repeat_interval: 4h    # Resend if alert still firing
  receiver: 'slack-default'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
      continue: false
    - match:
        team: backend
      receiver: 'slack-backend'

receivers:
  - name: 'slack-default'
    slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: '<pagerduty-service-key>'
        description: '{{ .GroupLabels.alertname }}: {{ .CommonAnnotations.summary }}'

  - name: 'slack-backend'
    slack_configs:
      - channel: '#backend-alerts'

inhibit_rules:
  # Suppress warning alerts when a critical alert for the same job fires
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: ['alertname', 'job']
```

---

## OpenTelemetry

OpenTelemetry (OTel) is the CNCF standard for unified telemetry. It provides vendor-neutral SDKs and a Collector that can route to any backend (Prometheus, Jaeger, Loki, Datadog, etc.).

### OTel Collector Config

The Collector runs as a DaemonSet or Deployment and acts as a telemetry pipeline.

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          static_configs:
            - targets: ['localhost:8888']

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
  resource:
    attributes:
      - key: service.environment
        value: "production"
        action: upsert
  # Add k8s metadata (pod name, namespace, node) to all telemetry
  k8sattributes:
    auth_type: serviceAccount
    extract:
      metadata:
        - k8s.pod.name
        - k8s.namespace.name
        - k8s.node.name
        - k8s.deployment.name

exporters:
  # Metrics → Prometheus remote write
  prometheusremotewrite:
    endpoint: "http://prometheus:9090/api/v1/write"
  # Traces → Jaeger
  jaeger:
    endpoint: "jaeger-collector:14250"
    tls:
      insecure: true
  # Traces → Tempo
  otlp/tempo:
    endpoint: "tempo:4317"
    tls:
      insecure: true
  # Logs → Loki
  loki:
    endpoint: "http://loki:3100/loki/api/v1/push"
  # Debug output
  logging:
    verbosity: normal

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, k8sattributes, batch]
      exporters: [jaeger, otlp/tempo]
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [loki]
```

### SDK Instrumentation

**Auto-instrumentation** (zero code changes, language-specific agent):

```yaml
# Kubernetes pod annotations for auto-instrumentation (cert-manager + OTel operator required)
annotations:
  instrumentation.opentelemetry.io/inject-python: "true"
  # Or: inject-java, inject-nodejs, inject-dotnet
```

**Manual instrumentation** (Python example):

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

resource = Resource.create({"service.name": "my-service", "service.version": "1.0.0"})
provider = TracerProvider(resource=resource)
exporter = OTLPSpanExporter(endpoint="http://otel-collector:4317", insecure=True)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)

def process_order(order_id: str):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.source", "web")
        try:
            result = do_processing(order_id)
            span.set_attribute("order.status", "success")
            return result
        except Exception as e:
            span.record_exception(e)
            span.set_status(trace.StatusCode.ERROR, str(e))
            raise
```

### Trace Context Propagation (W3C TraceContext)

W3C TraceContext is the standard. HTTP headers:
- `traceparent`: `00-{trace-id}-{parent-span-id}-{flags}` — e.g., `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`
- `tracestate`: vendor-specific key-value pairs

Propagation is handled automatically by OTel SDKs. For manual propagation:

```python
from opentelemetry import propagate
from opentelemetry.propagators.b3 import B3MultiFormat  # if using B3

# Inject context into outgoing request headers
headers = {}
propagate.inject(headers)
requests.get("http://downstream-service/api", headers=headers)

# Extract context from incoming request
context = propagate.extract(request.headers)
with tracer.start_as_current_span("handle_request", context=context):
    pass
```

### Metrics SDK

```python
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

reader = PeriodicExportingMetricReader(OTLPMetricExporter(endpoint="http://otel-collector:4317"))
provider = MeterProvider(resource=resource, metric_readers=[reader])
metrics.set_meter_provider(provider)

meter = metrics.get_meter(__name__)

# Counter: monotonically increasing
request_counter = meter.create_counter("http.requests.total", unit="1", description="Total HTTP requests")

# Histogram: latency distribution
latency_histogram = meter.create_histogram("http.request.duration", unit="s", description="Request duration")

# UpDownCounter: can go up or down (e.g., queue depth)
queue_depth = meter.create_up_down_counter("queue.depth", unit="1")

# Gauge: current value (e.g., CPU usage) — use Observable
cpu_gauge = meter.create_observable_gauge("system.cpu.usage", callbacks=[lambda _: [metrics.Observation(get_cpu_usage())]])
```

---

## Distributed Tracing

### Jaeger Setup (Kubernetes)

```yaml
# Using Jaeger Operator (recommended for production)
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: monitoring
spec:
  strategy: production   # production = separate components; allInOne = dev only
  storage:
    type: elasticsearch
    options:
      es:
        server-urls: http://elasticsearch:9200
  collector:
    replicas: 2
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
  query:
    replicas: 1
```

### Span Relationships

```
Trace: e2e request lifecycle
└── Span A: "api-gateway: POST /orders"  (root span, parent=nil)
    ├── Span B: "order-service: create_order"  (child of A)
    │   ├── Span C: "postgres: INSERT orders"  (child of B)
    │   └── Span D: "redis: SET order:123"  (child of B, sibling of C)
    └── Span E: "notification-service: send_email"  (child of A, follows-from B)
```

- **Child span**: Caused by parent, part of the same operation
- **Follows-from span**: Causally related but parent may have already finished (async)

### Sampling Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| Head-based (probabilistic) | Decision at trace start, e.g., 1% | Simple, low overhead |
| Head-based (rate-limiting) | N traces/second per service | Predictable volume |
| Tail-based | Decision after trace completes (can sample errors at 100%) | Best quality, higher memory |
| Always-on | 100% sampling | Dev/staging only |

Tail-based sampling in OTel Collector:

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    num_traces: 100000
    policies:
      - name: sample-errors
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: sample-slow
        type: latency
        latency: {threshold_ms: 1000}
      - name: probabilistic-baseline
        type: probabilistic
        probabilistic: {sampling_percentage: 1}
```

---

## Four Golden Signals + RED + USE

### Four Golden Signals (Google SRE)

| Signal | Description | Example Metric |
|--------|-------------|----------------|
| Latency | Time to serve a request | `histogram_quantile(0.99, rate(http_duration_bucket[5m]))` |
| Traffic | Demand on the system | `rate(http_requests_total[5m])` |
| Errors | Rate of failing requests | `rate(http_requests_total{status=~"5.."}[5m])` |
| Saturation | How "full" the service is | CPU/memory usage %, queue depth |

### RED Method (for services)

- **Rate**: Requests per second
- **Errors**: Error rate (%)
- **Duration**: Latency distribution (p50, p95, p99)

```promql
# RED dashboard queries
rate(http_requests_total[5m])                                          # Rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])  # Error rate
histogram_quantile(0.99, sum(rate(http_duration_bucket[5m])) by (le))  # p99 Duration
```

### USE Method (for resources)

- **Utilization**: % of time resource is busy
- **Saturation**: Extra work queued/waiting
- **Errors**: Error events

```promql
# USE for CPU
rate(node_cpu_seconds_total{mode!="idle"}[5m])  # CPU utilization
node_load1 / count(node_cpu_seconds_total{mode="idle"}) by (instance)  # CPU saturation
```

---

## SLO / SLI / SLA

| Term | Definition | Example |
|------|------------|---------|
| SLI (Indicator) | Measured metric | 99th percentile latency |
| SLO (Objective) | Target for the SLI | p99 latency < 200ms, measured over 30 days |
| SLA (Agreement) | SLO + consequences | SLO with contractual penalty |
| Error Budget | 100% - SLO target | 0.1% of requests can fail (43min/month for 99.9%) |

### Error Budget Calculation

```
SLO: 99.9% availability over 30 days
Error budget: 0.1% of 30 days = 43.2 minutes downtime allowed

If current burn rate = 2x → budget exhausted in 15 days
Alert: burn rate > 14.4x (budget gone in 2 hours)
```

### Multiwindow Error Budget Burn Rate Alerts

Alert when you're burning error budget too fast (Google's approach):

```yaml
# Burn rate alert: critical (1h + 5m windows, 14.4x burn)
- alert: ErrorBudgetBurnHighFast
  expr: |
    (
      1 - (
        sum(rate(http_requests_total{status!~"5.."}[1h]))
        / sum(rate(http_requests_total[1h]))
      )
    ) / (1 - 0.999) > 14.4
    and
    (
      1 - (
        sum(rate(http_requests_total{status!~"5.."}[5m]))
        / sum(rate(http_requests_total[5m]))
      )
    ) / (1 - 0.999) > 14.4
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Error budget burning at 14x rate — exhausted in 2h"

# Warning: 6x burn over 6h + 30m windows
- alert: ErrorBudgetBurnMedium
  expr: |
    (
      1 - (
        sum(rate(http_requests_total{status!~"5.."}[6h]))
        / sum(rate(http_requests_total[6h]))
      )
    ) / (1 - 0.999) > 6
    and
    (
      1 - (
        sum(rate(http_requests_total{status!~"5.."}[30m]))
        / sum(rate(http_requests_total[30m]))
      )
    ) / (1 - 0.999) > 6
  for: 15m
  labels:
    severity: warning
```

---

## APM Platforms

### Datadog Agent (Kubernetes DaemonSet)

```yaml
apiVersion: datadoghq.com/v2alpha1
kind: DatadogAgent
metadata:
  name: datadog
spec:
  global:
    credentials:
      apiKey: <DD_API_KEY>
      appKey: <DD_APP_KEY>
    clusterName: prod-us-east-1
  features:
    apm:
      enabled: true
    logCollection:
      enabled: true
      containerCollectAll: true
    liveProcesses:
      enabled: true
    orchestratorExplorer:
      enabled: true
```

### New Relic Agent (environment variables)

```yaml
# Inject into pod spec
env:
  - name: NEW_RELIC_LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: newrelic-license
        key: key
  - name: NEW_RELIC_APP_NAME
    value: "my-service"
  - name: NEW_RELIC_DISTRIBUTED_TRACING_ENABLED
    value: "true"
  - name: NEW_RELIC_LOG
    value: "stdout"
```

---

## Anti-Patterns

1. **Alert on every anomaly** — alert on symptoms (error rate high, latency spiking) not causes (CPU high). High-cardinality alerting creates alert fatigue
2. **No SLOs** — without SLOs, every alert feels equally urgent. Define error budgets first
3. **Sampling everything at 100%** — too expensive in production. Use 1% + always-sample errors
4. **Different tracing per service** — one team using Jaeger, another using Zipkin, another using X-Ray creates analysis nightmares. Standardize on OTel
5. **Logs without structure** — unstructured logs (`printf` style) can't be queried. Use JSON structured logging
6. **No correlation IDs** — traces need correlation across all three pillars. Propagate trace ID into logs
