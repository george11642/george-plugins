# Kubernetes Security & Policy

Security in Kubernetes requires defense in depth: policy enforcement at admission, network isolation, image security, RBAC, and supply chain controls. No single layer is sufficient.

## Pod Security Standards (PSP Replacement)

Kubernetes 1.25 removed PodSecurityPolicy (PSP). The replacement is **Pod Security Admission** (PSA), enforcing built-in profiles via namespace labels.

### Three Built-in Profiles

| Profile | Use Case | Restrictions |
|---------|----------|--------------|
| **Privileged** | System components (CNI, storage drivers) | No restrictions |
| **Baseline** | General workloads | Blocks known privilege escalations (no hostPID, no privileged containers) |
| **Restricted** | Security-sensitive workloads | Strict: non-root user, no privilege escalation, seccomp required |

### Namespace Enforcement Labels

```yaml
# Enforce restricted profile — pods violating it are rejected
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.29
    pod-security.kubernetes.io/audit: restricted    # Log violations
    pod-security.kubernetes.io/warn: restricted     # Warn on violation
```

Three modes per profile:
- `enforce`: Reject non-compliant pods
- `audit`: Allow but log to audit log
- `warn`: Allow but return warning in API response

### Migration from PSP

```bash
# 1. Audit current PSP usage
kubectl get psp
kubectl get clusterrolebinding | grep psp

# 2. Add warn/audit labels to namespaces first (non-blocking)
kubectl label namespace production \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# 3. Review audit logs for violations, fix workloads
# 4. Switch to enforce once workloads are compliant
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted

# 5. Remove PSP objects and bindings
```

---

## RBAC Deep Dive

### Least Privilege Principles

```yaml
# BAD: wildcard permissions
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]

# GOOD: specific resources and verbs
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader
  namespace: production
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["my-app-config"]   # Only this specific ConfigMap
    verbs: ["get"]
```

### ServiceAccount Per Application

Never use the `default` ServiceAccount — it may have unintended permissions.

```yaml
# Create dedicated SA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/my-app-role  # IRSA for AWS

---
# Bind minimal role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: my-app
    namespace: production
roleRef:
  kind: Role
  name: app-reader
  apiGroup: rbac.authorization.k8s.io

---
# Pod uses specific SA
spec:
  serviceAccountName: my-app
  automountServiceAccountToken: false   # Opt out if app doesn't use K8s API
```

### ClusterRole vs Role Scope

| Type | Scope | Use For |
|------|-------|---------|
| Role | Single namespace | Application-level permissions |
| ClusterRole | All namespaces | Admin functions, cross-namespace reads |
| RoleBinding | Namespace (can bind ClusterRole) | Namespace-scoped assignment |
| ClusterRoleBinding | Cluster-wide | Cluster admins, system components |

### Audit RBAC Permissions

```bash
# What can a ServiceAccount do?
kubectl auth can-i --list \
  --as=system:serviceaccount:production:my-app \
  --namespace=production

# Can it get secrets?
kubectl auth can-i get secrets \
  --as=system:serviceaccount:production:my-app \
  --namespace=production

# Find all ClusterRoleBindings that grant admin
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name == "cluster-admin") | .subjects'
```

---

## NetworkPolicy (Default-Deny Pattern)

By default, all pods can talk to all pods. NetworkPolicies are additive allow-rules — start from deny-all and explicitly allow needed traffic.

### Default Deny All (apply to every namespace)

```yaml
# Deny all ingress and egress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}    # Applies to all pods in namespace
  policyTypes:
    - Ingress
    - Egress
```

### Allow Specific Traffic

```yaml
# Allow frontend to reach backend on port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080

---
# Allow pods to reach kube-dns (required for DNS resolution)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53

---
# Allow backend to reach postgres in db namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: database
          podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
```

### Testing NetworkPolicies

```bash
# netshoot is a swiss-army networking debug container
kubectl run netshoot --rm -it \
  --image=nicolaka/netshoot \
  --labels="app=frontend" \
  --namespace=production \
  -- bash

# Inside: test connectivity
curl -v backend:8080/health
nc -zv postgres.database.svc.cluster.local 5432
```

---

## Image Security

### Image Scanning with Trivy

```bash
# Scan a local image
trivy image my-app:v1.2.3

# Scan with severity filter (fail CI on CRITICAL/HIGH)
trivy image --severity CRITICAL,HIGH --exit-code 1 my-app:v1.2.3

# Scan Kubernetes cluster for vulnerabilities
trivy k8s --report=summary cluster

# Scan in CI (GitHub Actions)
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_TAG }}
    format: sarif
    output: trivy-results.sarif
    severity: CRITICAL,HIGH
    exit-code: '1'
    ignore-unfixed: true
```

### Image Signing with Cosign (Sigstore)

```bash
# Generate a key pair (or use keyless with OIDC)
cosign generate-key-pair

# Sign an image after push
cosign sign --key cosign.key my-registry/my-app:v1.2.3

# Keyless signing (uses OIDC identity, no key management)
cosign sign my-registry/my-app:v1.2.3  # Prompts OIDC login

# Verify a signature
cosign verify --key cosign.pub my-registry/my-app:v1.2.3

# Sign with attestations (SBOM, vulnerability scan)
cosign attest --predicate sbom.json --type spdxjson \
  --key cosign.key my-registry/my-app:v1.2.3
```

### Base Image Selection

| Image | Size | Attack Surface | Use Case |
|-------|------|----------------|----------|
| `scratch` | 0 MB | Zero | Static Go binaries only |
| `distroless/static` | ~2 MB | Minimal (no shell) | Go, compiled binaries |
| `distroless/base` | ~20 MB | Small (glibc only) | Most compiled apps |
| `alpine` | ~5 MB | Small (has shell) | When shell access needed |
| `ubuntu/debian` | ~80 MB | Larger | When package manager needed |

```dockerfile
# Multi-stage: build on full image, run on distroless
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
```

---

## OPA Gatekeeper (Policy as Code)

OPA Gatekeeper enforces policies via admission webhooks. Policies are written in Rego.

### ConstraintTemplate (the policy definition)

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }
```

### Constraint (instantiate the policy)

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-team-label
spec:
  enforcementAction: deny    # deny | dryrun | warn
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet"]
    namespaces: ["production", "staging"]
  parameters:
    labels: ["team", "env", "service"]
```

### Image Registry Allowlist Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
      validation:
        openAPIV3Schema:
          type: object
          properties:
            repos:
              type: array
              items: {type: string}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedrepos

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not starts_with_allowed(container.image)
          msg := sprintf("Container image %v not from an allowed registry", [container.image])
        }

        starts_with_allowed(image) {
          repo := input.parameters.repos[_]
          startswith(image, repo)
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-registries
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    repos:
      - "my-registry.example.com/"
      - "gcr.io/my-project/"
```

---

## Kyverno (Kubernetes-Native Policies)

Kyverno policies are YAML — no Rego required. Easier to adopt but less expressive for complex logic.

### ClusterPolicy: Require Non-Root

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  validationFailureAction: Enforce   # Enforce | Audit
  background: true                   # Also check existing resources
  rules:
    - name: check-non-root
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: "Containers must run as non-root user"
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: true
```

### Mutation Policy: Add Default Labels

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-labels
spec:
  rules:
    - name: add-labels
      match:
        any:
          - resources:
              kinds: [Deployment]
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: kyverno
          spec:
            template:
              metadata:
                labels:
                  +(env): "unknown"   # Add only if not present
```

### Image Verification with Kyverno Sigstore

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-signature
      match:
        any:
          - resources:
              kinds: [Pod]
      verifyImages:
        - imageReferences:
            - "my-registry.example.com/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/my-org/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

---

## Supply Chain Security

### SLSA Framework Levels

| Level | Requirements | What It Proves |
|-------|-------------|----------------|
| SLSA 1 | Build process documented | Basic provenance |
| SLSA 2 | Hosted build service, signed provenance | Tamper evidence |
| SLSA 3 | Hardened build, non-falsifiable provenance | Build integrity |
| SLSA 4 | Hermetic build, reproducible | Full supply chain |

### SBOM Generation

```bash
# Generate SBOM with syft
syft my-app:v1.2.3 -o spdx-json=sbom.spdx.json

# Attach SBOM to image with cosign
cosign attach sbom --sbom sbom.spdx.json my-registry/my-app:v1.2.3

# Generate SBOM and attest it
cosign attest \
  --predicate sbom.spdx.json \
  --type spdxjson \
  --key cosign.key \
  my-registry/my-app:v1.2.3

# Verify SBOM attestation
cosign verify-attestation \
  --key cosign.pub \
  --type spdxjson \
  my-registry/my-app:v1.2.3 | jq '.payload | @base64d | fromjson'
```

### Dependency Scanning in CI

```yaml
# GitHub Actions — scan dependencies + container
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'              # Scan filesystem (dependencies)
    scan-ref: '.'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy results to GitHub Security
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

---

## Anti-Patterns

1. **No NetworkPolicies** — Kubernetes default is allow-all. Any compromised pod can reach any other pod. Default-deny is non-negotiable in production
2. **Using `default` ServiceAccount** — it gets cluster permissions you don't realize. Always create dedicated SAs
3. **Running as root** — most container exploits pivot through root. `runAsNonRoot: true` + `allowPrivilegeEscalation: false` on every container
4. **PSP migration skipped** — orgs that didn't migrate to PSA before 1.25 lost all pod security controls silently
5. **Scanning only in CI but not at runtime** — new CVEs emerge after deploy. Run periodic cluster scans with Trivy
6. **Policy in warn mode forever** — use `warn`/`dryrun` to onboard, but set a date to switch to `enforce`. Policies that never enforce are theater
