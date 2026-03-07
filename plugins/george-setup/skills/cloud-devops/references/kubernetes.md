# Kubernetes Reference

## Core Objects

### Pod

The smallest deployable unit. Never deploy naked pods -- always use a controller (Deployment, StatefulSet, Job).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
  labels:
    app: myapp
spec:
  containers:
    - name: app
      image: app:v1.2.3
      ports:
        - containerPort: 8080
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 15
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /ready
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 5
      env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
```

Why both liveness AND readiness probes: liveness restarts crashed containers. Readiness removes unready pods from service endpoints. Without readiness, K8s routes traffic to pods still starting up.

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: myapp
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: app
          image: app:v1.2.3
          # ... (ports, probes, resources as above)
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: myapp
```

Why `maxUnavailable: 0`: ensures zero downtime during rolling updates. Combined with `maxSurge: 1`, K8s creates one new pod, waits for it to be ready, then removes one old pod.

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP  # Internal only. Use LoadBalancer for external, or Ingress
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app
                port:
                  number: 80
```

### HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
```

Why stabilization window: prevents flapping. Without it, a brief traffic dip triggers scale-down, then immediate scale-up when traffic returns.

## Deployment Strategies

| Strategy | How | When |
|----------|-----|------|
| Rolling update | Replace pods incrementally | Default, works for most services |
| Blue-green | Run two full environments, switch traffic | Need instant rollback, can afford 2x resources |
| Canary | Route small % of traffic to new version | High-risk changes, need gradual validation |
| Recreate | Kill all old, create all new | Stateful apps that can't run two versions |

### Canary with Ingress

```yaml
# Canary deployment -- receives 10% of traffic
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-canary
                port:
                  number: 80
```

## Helm

### Chart Structure

```
mychart/
  Chart.yaml          # Chart metadata, version, dependencies
  values.yaml         # Default configuration values
  values-prod.yaml    # Production overrides
  templates/
    deployment.yaml   # Templated K8s manifests
    service.yaml
    ingress.yaml
    _helpers.tpl      # Template helper functions
    NOTES.txt         # Post-install instructions
```

### Key Helm Commands

```bash
# Install/upgrade a release
helm upgrade --install app ./mychart -f values-prod.yaml -n production

# Preview what will be applied
helm template app ./mychart -f values-prod.yaml

# Show diff before upgrade (requires helm-diff plugin)
helm diff upgrade app ./mychart -f values-prod.yaml

# Rollback to previous release
helm rollback app 1

# List releases
helm list -n production
```

### Values Best Practices

```yaml
# values.yaml -- sensible defaults, override per environment
replicaCount: 2
image:
  repository: app
  tag: "v1.0.0"  # Always quote tags -- YAML treats 1.0 as a float
  pullPolicy: IfNotPresent
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
ingress:
  enabled: false
  host: ""
```

## Monitoring and Observability

### Prometheus Annotations

```yaml
# Add to pod template metadata
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"
```

### Key Metrics to Monitor

| Metric | What it tells you | Alert threshold |
|--------|-------------------|-----------------|
| Container restarts | Crash loops | > 3 in 5 minutes |
| CPU throttling | Resource starvation | > 25% of periods throttled |
| Memory working set | OOM risk | > 80% of limit |
| Pod pending duration | Scheduling issues | > 5 minutes |
| HTTP 5xx rate | Application errors | > 1% of requests |
| Request latency p99 | Performance degradation | > 2x baseline |

## Troubleshooting

### Pod Won't Start

```bash
# Check events for scheduling/pull errors
kubectl describe pod <name> -n <ns>

# Common causes:
# - ImagePullBackOff: wrong image name/tag, no pull secret
# - CrashLoopBackOff: app crashes on start, check logs
# - Pending: insufficient resources, check node capacity
# - OOMKilled: memory limit too low, increase limits

kubectl get events --sort-by=.lastTimestamp -n <ns>
kubectl top nodes  # Check cluster capacity
kubectl top pods -n <ns>  # Check pod resource usage
```

### Service Not Reachable

```bash
# Verify endpoints exist (pods matched by selector)
kubectl get endpoints <service> -n <ns>

# If empty: labels don't match between Service selector and Pod labels
kubectl get pods -l app=myapp -n <ns>

# Test from inside the cluster
kubectl run debug --rm -it --image=nicolaka/netshoot -- bash
# Then: curl http://service.namespace.svc.cluster.local:80

# Check network policies blocking traffic
kubectl get networkpolicies -n <ns>
```

### DNS Debugging

```bash
kubectl run dnsutils --rm -it --image=gcr.io/kubernetes-e2e-test-images/dnsutils -- bash
nslookup kubernetes.default
nslookup myservice.mynamespace.svc.cluster.local
```

## Security Best Practices

1. **Pod Security Standards** -- enforce `restricted` profile in production namespaces
2. **Network Policies** -- default-deny ingress, explicitly allow required traffic
3. **RBAC** -- service accounts per app, ClusterRoles only when truly needed
4. **Secrets** -- use external-secrets-operator to sync from Vault/AWS Secrets Manager, never commit Secret manifests
5. **Image policies** -- only allow images from trusted registries, require signed images
6. **Resource quotas** -- set per-namespace quotas to prevent resource hogging

### Default Deny NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

## Common Gotchas

1. **Forgetting resource requests** -- without requests, the scheduler can't make informed placement decisions, leading to overcommitted nodes
2. **ConfigMap/Secret updates don't restart pods** -- use a hash annotation or Reloader controller to trigger rolling restarts
3. **PersistentVolumeClaim stuck in Pending** -- check StorageClass exists and has available capacity
4. **DNS takes 30s to update** -- after pod deletion, stale DNS entries linger. Use `publishNotReadyAddresses: true` on headless services if needed
5. **Node affinity vs pod affinity** -- node affinity places pods on specific nodes; pod affinity/anti-affinity places pods relative to other pods
