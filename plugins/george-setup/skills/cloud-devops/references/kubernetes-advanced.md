# Kubernetes Advanced

Beyond basic deployments: extending Kubernetes with custom resources, building operators, advanced scheduling, cluster operations, disaster recovery, and multi-tenancy.

## Custom Resource Definitions (CRDs)

CRDs extend the Kubernetes API with custom resource types without modifying the core API server.

### CRD Spec with Validation

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myapps.example.com
spec:
  group: example.com
  names:
    plural: myapps
    singular: myapp
    kind: MyApp
    shortNames: [ma]           # kubectl get ma
    categories: [all]          # Included in: kubectl get all
  scope: Namespaced            # or Cluster
  versions:
    - name: v1
      served: true
      storage: true            # Only one version can be the storage version
      schema:
        openAPIV3Schema:
          type: object
          required: [spec]
          properties:
            spec:
              type: object
              required: [image, replicas]
              properties:
                image:
                  type: string
                  pattern: '^[\w./-]+:[\w.-]+$'   # Basic image:tag format
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 100
                  default: 1
                env:
                  type: array
                  items:
                    type: object
                    required: [name, value]
                    properties:
                      name: {type: string}
                      value: {type: string}
                # CEL validation (Kubernetes 1.25+)
                resources:
                  type: object
                  x-kubernetes-validations:
                    - rule: "self.requests.cpu <= self.limits.cpu"
                      message: "CPU requests must not exceed limits"
                  properties:
                    requests:
                      type: object
                      properties:
                        cpu: {type: string}
                        memory: {type: string}
                    limits:
                      type: object
                      properties:
                        cpu: {type: string}
                        memory: {type: string}
            status:
              type: object
              properties:
                availableReplicas:
                  type: integer
                conditions:
                  type: array
                  items:
                    type: object
                    required: [type, status]
                    properties:
                      type: {type: string}
                      status: {type: string}
                      reason: {type: string}
                      message: {type: string}
                      lastTransitionTime: {type: string, format: date-time}
      subresources:
        status: {}              # Enable /status subresource (separate RBAC)
        scale:                  # Enable HPA targeting
          specReplicasPath: .spec.replicas
          statusReplicasPath: .status.availableReplicas
      additionalPrinterColumns:
        - name: Replicas
          type: integer
          jsonPath: .spec.replicas
        - name: Image
          type: string
          jsonPath: .spec.image
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
```

### CEL Validation Expressions (Kubernetes 1.25+)

CEL (Common Expression Language) runs validation in the API server — faster than admission webhooks and no extra component.

```yaml
x-kubernetes-validations:
  # Cross-field validation
  - rule: "self.minReplicas <= self.maxReplicas"
    message: "minReplicas must be <= maxReplicas"
  # Immutability (once set, can't change)
  - rule: "self.region == oldSelf.region"
    message: "region is immutable after creation"
  # Complex logic
  - rule: "!(self.highAvailability && self.replicas < 3)"
    message: "highAvailability requires at least 3 replicas"
```

### Versioning and Conversion Webhooks

When you need a new CRD version with breaking schema changes, use a conversion webhook to translate between versions.

```yaml
# CRD with conversion webhook
spec:
  conversion:
    strategy: Webhook
    webhook:
      conversionReviewVersions: ["v1", "v1beta1"]
      clientConfig:
        service:
          name: myapp-conversion-webhook
          namespace: system
          path: /convert
        caBundle: <base64-encoded-CA>
  versions:
    - name: v1       # New version
      served: true
      storage: true
    - name: v1beta1  # Old version — still served but not stored
      served: true
      storage: false
```

---

## Operator Pattern

Operators encode operational knowledge as code. A controller watches CRDs and reconciles the desired state.

### Reconcile Loop (controller-runtime)

```go
// Reconciler implements the core logic
type MyAppReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

func (r *MyAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // 1. Fetch the custom resource
    myapp := &examplev1.MyApp{}
    if err := r.Get(ctx, req.NamespacedName, myapp); err != nil {
        if errors.IsNotFound(err) {
            return ctrl.Result{}, nil  // Deleted — nothing to do
        }
        return ctrl.Result{}, err
    }

    // 2. Check if being deleted (finalizer pattern)
    if myapp.DeletionTimestamp != nil {
        if controllerutil.ContainsFinalizer(myapp, myFinalizer) {
            if err := r.cleanup(ctx, myapp); err != nil {
                return ctrl.Result{}, err
            }
            controllerutil.RemoveFinalizer(myapp, myFinalizer)
            if err := r.Update(ctx, myapp); err != nil {
                return ctrl.Result{}, err
            }
        }
        return ctrl.Result{}, nil
    }

    // 3. Add finalizer if not present
    if !controllerutil.ContainsFinalizer(myapp, myFinalizer) {
        controllerutil.AddFinalizer(myapp, myFinalizer)
        if err := r.Update(ctx, myapp); err != nil {
            return ctrl.Result{}, err
        }
    }

    // 4. Reconcile child resources (Deployment, Service)
    if err := r.reconcileDeployment(ctx, myapp); err != nil {
        meta.SetStatusCondition(&myapp.Status.Conditions, metav1.Condition{
            Type:    "Available",
            Status:  metav1.ConditionFalse,
            Reason:  "ReconcileError",
            Message: err.Error(),
        })
        _ = r.Status().Update(ctx, myapp)
        return ctrl.Result{}, err
    }

    // 5. Update status
    meta.SetStatusCondition(&myapp.Status.Conditions, metav1.Condition{
        Type:    "Available",
        Status:  metav1.ConditionTrue,
        Reason:  "Reconciled",
        Message: "MyApp is running",
    })
    if err := r.Status().Update(ctx, myapp); err != nil {
        return ctrl.Result{}, err
    }

    // Requeue after 5 minutes for drift detection
    return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}

// Setup watches
func (r *MyAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&examplev1.MyApp{}).             // Watch primary resource
        Owns(&appsv1.Deployment{}).           // Requeue when owned Deployment changes
        Owns(&corev1.Service{}).
        Complete(r)
}
```

### Operator SDK vs Kubebuilder

| Tool | Language | Scaffolding | Ansible/Helm support |
|------|----------|-------------|---------------------|
| Kubebuilder | Go only | Minimal, clean | No |
| Operator SDK | Go, Ansible, Helm | More opinionated | Yes |

Both use controller-runtime under the hood. Kubebuilder for pure Go operators; Operator SDK when you want Helm/Ansible operators.

---

## Admission Webhooks

Admission webhooks intercept API server requests before objects are persisted.

### ValidatingAdmissionWebhook

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: my-validator
webhooks:
  - name: validate.myapp.example.com
    admissionReviewVersions: ["v1"]
    clientConfig:
      service:
        name: my-webhook-svc
        namespace: webhook-system
        path: /validate
      caBundle: <base64-CA>
    rules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        resources: ["deployments"]
        operations: ["CREATE", "UPDATE"]
    failurePolicy: Fail   # Fail | Ignore — Fail = reject if webhook unavailable
    sideEffects: None     # Required: None | NoneOnDryRun
    timeoutSeconds: 10
    namespaceSelector:
      matchExpressions:
        - key: kubernetes.io/metadata.name
          operator: NotIn
          values: [kube-system, kube-public]
```

### MutatingAdmissionWebhook

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: my-mutator
webhooks:
  - name: mutate.myapp.example.com
    admissionReviewVersions: ["v1"]
    clientConfig:
      service:
        name: my-webhook-svc
        namespace: webhook-system
        path: /mutate
      caBundle: <base64-CA>
    rules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
        operations: ["CREATE"]
    failurePolicy: Ignore   # Non-critical mutation = Ignore
    sideEffects: None
    reinvocationPolicy: Never   # IfNeeded if mutation triggers another mutation
```

### Webhook Server Response (JSON patch)

```go
// Return admission response with JSON patch
func mutate(ar *admissionv1.AdmissionReview) *admissionv1.AdmissionResponse {
    pt := admissionv1.PatchTypeJSONPatch
    patches := []map[string]interface{}{
        {
            "op":    "add",
            "path":  "/metadata/labels/injected-by",
            "value": "my-webhook",
        },
        {
            "op":    "replace",
            "path":  "/spec/securityContext/runAsNonRoot",
            "value": true,
        },
    }
    patchBytes, _ := json.Marshal(patches)
    return &admissionv1.AdmissionResponse{
        UID:       ar.Request.UID,
        Allowed:   true,
        Patch:     patchBytes,
        PatchType: &pt,
    }
}
```

### TLS Certificate Management

Webhook servers require TLS. Use cert-manager to auto-provision and rotate:

```yaml
# Certificate for webhook server
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webhook-server-cert
  namespace: webhook-system
spec:
  secretName: webhook-server-tls
  dnsNames:
    - my-webhook-svc.webhook-system.svc
    - my-webhook-svc.webhook-system.svc.cluster.local
  issuerRef:
    name: cluster-ca
    kind: ClusterIssuer
```

---

## Advanced Scheduling

### Pod Affinity / Anti-Affinity

```yaml
spec:
  affinity:
    # Required: spread replicas across zones (no two on same zone)
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values: [my-app]
          topologyKey: topology.kubernetes.io/zone

    # Preferred: co-locate with cache pods (soft requirement)
    podAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: redis-cache
            topologyKey: kubernetes.io/hostname
```

### Taints and Tolerations (Dedicated Nodes)

```yaml
# Taint a node (e.g., GPU node for ML workloads only)
kubectl taint nodes gpu-node-1 dedicated=gpu:NoSchedule

# Pod must tolerate the taint
spec:
  tolerations:
    - key: dedicated
      operator: Equal
      value: gpu
      effect: NoSchedule
  nodeSelector:
    dedicated: gpu
```

### Topology Spread Constraints

More powerful than anti-affinity: ensures even distribution across zones/nodes.

```yaml
spec:
  topologySpreadConstraints:
    # Spread evenly across zones, max skew of 1
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule   # Hard requirement
      labelSelector:
        matchLabels:
          app: my-app
    # Also spread across nodes within each zone
    - maxSkew: 2
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway  # Soft requirement
      labelSelector:
        matchLabels:
          app: my-app
```

### PriorityClasses

```yaml
# Define priority classes
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "Critical production workloads"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
preemptionPolicy: Never   # Won't preempt other pods
description: "Batch and non-critical workloads"

# Reference in pod spec
spec:
  priorityClassName: high-priority
```

---

## Cluster Operations

### Cluster Upgrade (Best Practice)

```bash
# 1. Check current versions
kubectl version
kubeadm version

# 2. Upgrade control plane first (one minor version at a time: 1.28 → 1.29 → 1.30)
# On control plane node:
apt-get update && apt-get install -y kubeadm=1.29.x-00
kubeadm upgrade plan           # Show available upgrades
kubeadm upgrade apply v1.29.0  # Upgrade control plane components
apt-get install -y kubelet=1.29.x-00 kubectl=1.29.x-00
systemctl restart kubelet

# 3. Upgrade worker nodes (rolling, one at a time)
kubectl cordon <node-name>           # Mark unschedulable
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=300

# On worker node:
apt-get install -y kubeadm=1.29.x-00
kubeadm upgrade node
apt-get install -y kubelet=1.29.x-00
systemctl restart kubelet

kubectl uncordon <node-name>         # Re-enable scheduling
```

### etcd Backup and Restore

etcd is the Kubernetes brain. Back it up before any major operation.

```bash
# Backup (run on control plane or etcd node)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d_%H%M).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-20250101_1200.db --write-out=table

# Restore (cluster must be stopped first)
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-20250101_1200.db \
  --data-dir=/var/lib/etcd-restore \
  --name=<node-name> \
  --initial-cluster=<node-name>=https://<ip>:2380 \
  --initial-advertise-peer-urls=https://<ip>:2380

# Update etcd static pod manifest to point to new data dir
# Then restart kubelet
```

### API Server Audit Logging

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log secret access at metadata level (not contents)
  - level: Metadata
    resources:
      - group: ""
        resources: [secrets, configmaps]
  # Log all writes
  - level: RequestResponse
    verbs: [create, update, patch, delete]
  # Log authentication failures
  - level: Metadata
    users: ["system:anonymous"]
  # Skip noisy read-only operations
  - level: None
    verbs: [get, list, watch]
    users: ["system:kube-proxy", "system:node"]
```

---

## Disaster Recovery

### Velero Backup

Velero backs up Kubernetes resources and optionally PersistentVolume data.

```bash
# Install Velero with AWS S3 backend
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket my-velero-backups \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --secret-file ./credentials-velero

# Create a scheduled backup (every 6 hours, keep 7 days)
velero schedule create daily-backup \
  --schedule="0 */6 * * *" \
  --ttl 168h0m0s \
  --include-namespaces production,staging \
  --snapshot-volumes=true

# Manual backup before cluster upgrade
velero backup create pre-upgrade-backup \
  --include-namespaces production \
  --snapshot-volumes=true \
  --wait

# Check backup status
velero backup describe pre-upgrade-backup --details

# Restore
velero restore create --from-backup pre-upgrade-backup \
  --include-namespaces production \
  --wait
```

### Volume Snapshots with Velero

```yaml
# VolumeSnapshotLocation — where to store volume snapshots
apiVersion: velero.io/v1
kind: VolumeSnapshotLocation
metadata:
  name: aws-east-1
  namespace: velero
spec:
  provider: aws
  config:
    region: us-east-1
    profile: default
```

### Multi-Cluster Failover Patterns

**Active-Passive (AWS EKS)**:
1. Primary cluster (us-east-1) serves all traffic
2. Standby cluster (us-west-2) has Velero restores synced every 6h
3. Failover: update Route53 weighted routing to standby, restore latest backup

**Active-Active (GKE)**:
1. Two clusters in different regions, both serving traffic
2. Global load balancer (Cloud Load Balancing) distributes traffic
3. Shared database (Spanner or multi-region PostgreSQL)
4. GitOps ensures both clusters have identical application configuration

**Key RPO/RTO targets**:
- Backup frequency determines RPO (Recovery Point Objective)
- Restore speed determines RTO (Recovery Time Objective)
- Velero restore for 50GB of resources: typically 15-30 minutes

---

## Multi-Tenancy

### Namespace Isolation

Namespaces are the primary tenancy boundary. Combine with ResourceQuota, NetworkPolicy, and RBAC:

```yaml
# Per-team namespace setup
apiVersion: v1
kind: Namespace
metadata:
  name: team-backend
  labels:
    team: backend
    pod-security.kubernetes.io/enforce: restricted

---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-backend
spec:
  hard:
    requests.cpu: "16"
    requests.memory: 32Gi
    limits.cpu: "32"
    limits.memory: 64Gi
    pods: "50"
    services.loadbalancers: "2"
    persistentvolumeclaims: "20"
    count/deployments.apps: "20"

---
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-backend
spec:
  limits:
    - type: Container
      default:           # Default limits if not specified
        cpu: 500m
        memory: 512Mi
      defaultRequest:    # Default requests if not specified
        cpu: 100m
        memory: 128Mi
      max:
        cpu: "4"
        memory: 4Gi
      min:
        cpu: 50m
        memory: 64Mi
```

### Virtual Clusters (vCluster)

For stronger isolation (separate API server per tenant), use vCluster:

```bash
# Install vcluster CLI
# Create a virtual cluster for a team
vcluster create team-backend \
  --namespace team-backend \
  --chart-version 0.19.0

# Connect to virtual cluster
vcluster connect team-backend --namespace team-backend

# Inside vcluster: full K8s API, own namespaces, own RBAC
# Workloads schedule to host cluster nodes (synced)
kubectl get nodes   # Shows host cluster nodes
kubectl create namespace my-app  # Virtual namespace
```

vCluster use cases:
- CI/CD: ephemeral test clusters without full cluster cost
- SaaS: per-customer K8s environments on shared infrastructure
- Development: developers get admin access without cluster-admin on host

---

## Anti-Patterns

1. **Operators without finalizers** — if operator is deleted before the CR, Kubernetes orphans child resources. Always implement finalizer cleanup
2. **Webhook failure policy Fail without HA** — a single-replica webhook with `failurePolicy: Fail` becomes a cluster availability dependency. Run 2+ replicas
3. **No CRD validation** — without `openAPIV3Schema`, any JSON is accepted. Define schema from day one; retrofitting validation breaks existing objects
4. **Skipping minor versions during upgrade** — Kubernetes only supports one-version skips for `kubectl`. Always upgrade one minor version at a time
5. **No etcd backup schedule** — manual backups before upgrades are good but not sufficient. Schedule automated backups to object storage daily
6. **ResourceQuota without LimitRange** — without default LimitRange, pods without resource requests bypass quota accounting (requests.cpu = 0)
