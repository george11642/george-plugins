# Service Mesh

A service mesh adds a dedicated infrastructure layer for service-to-service communication. It provides mTLS, observability, and traffic management *without modifying application code* — the logic lives in sidecar proxies injected alongside each pod.

## Why Service Mesh?

| Problem | Service Mesh Solution |
|---------|----------------------|
| No encryption between services | Automatic mTLS — all traffic encrypted by default |
| Manual retry/timeout logic in every service | Retries, timeouts, circuit breakers in the proxy |
| No visibility into inter-service traffic | Automatic RED metrics, distributed traces, service graph |
| Hard to do canary deploys | Traffic splitting by percentage or header |
| Zero-trust networking | L7 AuthorizationPolicies per service identity |

**When you don't need a service mesh**: Fewer than 10 services, monolith, batch workloads, or teams without the operational expertise to maintain it. Meshes add real complexity.

## Comparison: Istio vs Linkerd vs Cilium

| Feature | Istio | Linkerd | Cilium |
|---------|-------|---------|--------|
| Proxy | Envoy | Linkerd2-proxy (Rust) | eBPF (no sidecar) |
| mTLS | Yes | Yes | Yes |
| Traffic management | Rich (VirtualService, DR) | Basic | Basic |
| Observability | Rich (metrics, traces, logs) | Good | Good |
| Performance overhead | Higher (~10ms, ~100MB/sidecar) | Lower (~1ms, ~50MB) | Lowest (eBPF) |
| Complexity | High | Medium | Medium |
| Multi-cluster | Yes | Yes | Yes |
| WASM extensibility | Yes (Envoy) | No | No |
| Best for | Full-featured, complex routing | Simple mTLS + observability | Performance-critical, K8s 1.26+ |

---

## Istio Fundamentals

### Core Resources

**VirtualService** — routing rules for traffic entering a service:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
  namespace: production
spec:
  hosts:
    - my-service                    # K8s service name
    - my-service.example.com        # External hostname
  gateways:
    - production/my-ingress-gateway # Route from gateway
    - mesh                          # Route from within cluster
  http:
    # Canary: 10% to v2, 90% to v1
    - match:
        - headers:
            x-canary:
              exact: "true"         # Header-based routing (A/B test)
      route:
        - destination:
            host: my-service
            subset: v2
    - route:
        - destination:
            host: my-service
            subset: v1
          weight: 90
        - destination:
            host: my-service
            subset: v2
          weight: 10
      timeout: 10s
      retries:
        attempts: 3
        perTryTimeout: 3s
        retryOn: "gateway-error,connect-failure,retriable-4xx"
      fault:                        # Fault injection (chaos testing)
        delay:
          percentage:
            value: 5.0
          fixedDelay: 5s
```

**DestinationRule** — policies for traffic to a destination (load balancing, circuit breaker, mTLS, subsets):

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-service
  namespace: production
spec:
  host: my-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    loadBalancer:
      simple: LEAST_CONN   # ROUND_ROBIN | LEAST_CONN | RANDOM
    outlierDetection:       # Circuit breaker
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
    tls:
      mode: ISTIO_MUTUAL    # ISTIO_MUTUAL (auto) | MUTUAL | SIMPLE | DISABLE
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
      trafficPolicy:
        loadBalancer:
          simple: ROUND_ROBIN
```

**Gateway** — ingress/egress traffic entering the mesh:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-ingress-gateway
  namespace: production
spec:
  selector:
    istio: ingressgateway    # Targets the Istio ingress gateway pods
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: my-cert-tls   # K8s TLS secret (managed by cert-manager)
      hosts:
        - my-service.example.com
    - port:
        number: 80
        name: http
        protocol: HTTP
      tls:
        httpsRedirect: true
      hosts:
        - my-service.example.com
```

**ServiceEntry** — register external services in the mesh:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-api
spec:
  hosts:
    - api.external-vendor.com
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  resolution: DNS
  location: MESH_EXTERNAL
```

**PeerAuthentication** — mTLS enforcement per namespace or workload:

```yaml
# Enforce strict mTLS for entire namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT   # STRICT | PERMISSIVE | DISABLE

# PERMISSIVE allows both mTLS and plaintext — useful during migration
```

**AuthorizationPolicy** — L7 access control (who can call what):

```yaml
# Only allow frontend to call backend's /api path
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-allow
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/production/sa/frontend"  # SPIFFE identity
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/*"]
```

---

## Traffic Management Patterns

### Canary Deployment (Weight-Based)

```yaml
# Phase 1: 5% canary
# VirtualService weight: v1=95, v2=5

# Phase 2 (after validation): 25%
# Phase 3 (after metrics pass): 100%
# Phase 4: Remove v1 Deployment

# Automate with Argo Rollouts + Istio integration
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      canaryService: my-service-canary
      stableService: my-service-stable
      trafficRouting:
        istio:
          virtualService:
            name: my-service
            routes:
              - primary
      steps:
        - setWeight: 5
        - pause: {duration: 10m}
        - setWeight: 25
        - pause: {}   # Manual gate
        - setWeight: 100
```

### A/B Testing by Header

```yaml
# VirtualService: route users with x-version: beta to v2
http:
  - match:
      - headers:
          x-version:
            exact: "beta"
    route:
      - destination:
          host: my-service
          subset: v2
  - route:
      - destination:
          host: my-service
          subset: v1
```

### Traffic Mirroring (Shadow Mode)

Send a copy of production traffic to a new version without affecting users. Used for validation.

```yaml
http:
  - route:
      - destination:
          host: my-service
          subset: v1
        weight: 100
    mirror:
      host: my-service
      subset: v2
    mirrorPercentage:
      value: 100.0   # Mirror 100% of traffic to v2 (responses ignored)
```

### Fault Injection for Chaos Testing

```yaml
# Inject 5s delay for 10% of requests
http:
  - fault:
      delay:
        percentage:
          value: 10.0
        fixedDelay: 5s
      abort:
        percentage:
          value: 2.0
        httpStatus: 503    # Abort 2% of requests with 503
    route:
      - destination:
          host: my-service
```

---

## Observability with Service Mesh

Istio automatically generates telemetry without code changes:

### Automatic Metrics (Prometheus)

Every Envoy proxy emits these metrics:
```promql
# Request rate per service
sum(rate(istio_requests_total[5m])) by (destination_service_name)

# Error rate (4xx + 5xx)
sum(rate(istio_requests_total{response_code=~"[45].."}[5m])) by (destination_service_name)
/
sum(rate(istio_requests_total[5m])) by (destination_service_name)

# P99 latency per service
histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (destination_service_name, le))
```

### Distributed Tracing

Istio auto-injects trace headers but requires services to *propagate* them (pass through incoming trace headers on outbound calls). The Envoy proxy creates spans automatically for all traffic.

```python
# Services must propagate these headers from incoming to outgoing requests
TRACE_HEADERS = [
    'x-request-id',
    'x-b3-traceid',
    'x-b3-spanid',
    'x-b3-parentspanid',
    'x-b3-sampled',
    'x-b3-flags',
    'b3',
    'traceparent',   # W3C TraceContext
    'tracestate',
]

@app.route('/api/orders')
def get_orders():
    headers = {h: request.headers[h] for h in TRACE_HEADERS if h in request.headers}
    response = requests.get('http://inventory-service/items', headers=headers)
    return response.json()
```

### Service Graph (Kiali)

Kiali provides a real-time service graph showing traffic flow, error rates, and latency between services. Install with:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
istioctl dashboard kiali
```

---

## Debugging Istio

```bash
# Check all proxies are synced with istiod
istioctl proxy-status

# Analyze configuration issues (common errors, deprecated APIs)
istioctl analyze --namespace production

# Describe a pod's proxy config (effective policies)
istioctl experimental describe pod my-pod-xyz -n production

# View Envoy configuration for a pod
istioctl proxy-config all my-pod-xyz -n production

# Envoy admin interface (from within pod or port-forward)
kubectl port-forward my-pod-xyz 15000:15000 -n production
# Then: http://localhost:15000/config_dump
# http://localhost:15000/stats/prometheus

# Check iptables rules in a pod (traffic interception)
kubectl exec -it my-pod-xyz -n production -c istio-proxy -- \
  sudo iptables -t nat -L -n -v

# View access logs (if enabled)
kubectl logs my-pod-xyz -c istio-proxy -n production

# Enable access logging globally
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  accessLogging:
    - providers:
        - name: envoy
```

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| 503 errors | Destination not in mesh or no DestinationRule | Check `istioctl analyze` |
| mTLS failures | PeerAuthentication STRICT but client not in mesh | Add to mesh or use PERMISSIVE |
| No traces | Service not propagating headers | Add header propagation code |
| High latency | Envoy timeout too short | Increase timeout in VirtualService |
| Proxy not injecting | Namespace not labeled | `kubectl label namespace X istio-injection=enabled` |

---

## Production Deployment Tips

1. **Resource budget**: ~0.5 CPU cores and ~50MB memory per sidecar. For 100 pods, that's 50 CPU cores and 5GB memory just for proxies. Factor into node sizing.
2. **Start with PERMISSIVE mTLS**: Migrate services into the mesh gradually. Switch to STRICT only after all consumers are in the mesh.
3. **Mesh non-critical services first**: Validate setup on dev/staging workloads before production.
4. **GitOps for Istio resources**: Store all VirtualServices, DestinationRules, and policies in Git. Use ArgoCD/Flux to apply them.
5. **Multi-cluster Istio**: Use `istioctl install --set profile=remote` on secondary clusters with a shared trust domain. Enables cross-cluster service discovery.

---

## Anti-Patterns

1. **Mesh everything on day one** — start with 5-10 services, learn the operational model, expand gradually
2. **No traffic policies after enabling mTLS** — mTLS encrypts traffic but AuthorizationPolicy enforces which services can call which. Both are needed for zero-trust
3. **VirtualService without DestinationRule** — traffic policies (circuit breaker, load balancing, mTLS mode) live in DestinationRule. VirtualService routing without DR subsets will fail
4. **Forgetting header propagation** — traces will be fragmented. Propagation is a code change in every service — plan for it
5. **Ignoring proxy resource limits** — in large clusters, Envoy sidecars become a significant compute cost. Right-size them per workload
