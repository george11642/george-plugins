# GitOps

GitOps is an operational model where Git is the single source of truth for declarative infrastructure and application configuration. Kubernetes clusters continuously reconcile their state to match what's in Git — enabling auditable, reversible, and automated deployments.

## Core Principles

1. **Declarative**: Desired system state described declaratively (YAML manifests, Helm values, Kustomize overlays)
2. **Versioned and immutable**: Git history is the audit trail — every change is a commit with author, timestamp, and reason
3. **Pull-based**: Agents *inside* the cluster pull from Git. No external system needs cluster credentials
4. **Automatically reconciled**: Software agents continuously detect and correct drift between desired (Git) and actual (live cluster) state

Pull-based is the security win: the cluster reaches out to Git, not the other way around. No inbound firewall rules to open, no kubeconfig files stored in CI runners.

---

## ArgoCD

ArgoCD is the most widely adopted GitOps tool with a rich UI, strong multi-cluster support, and deep Kubernetes integration.

### Application CRD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # Deletes K8s resources when Application is deleted
spec:
  project: default

  source:
    repoURL: https://github.com/my-org/k8s-manifests
    targetRevision: main             # Branch, tag, or commit SHA
    path: apps/my-app/overlays/prod  # Kustomize overlay path

  destination:
    server: https://kubernetes.default.svc   # In-cluster target
    namespace: production

  syncPolicy:
    automated:
      prune: true       # Delete resources removed from Git
      selfHeal: true    # Revert manual changes to cluster
      allowEmpty: false # Prevent accidental deletion of all resources
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - ApplyOutOfSyncOnly=true    # Only apply changed resources (faster)
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Sync Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| Manual | Sync only when explicitly triggered | Production with approval gates |
| Automatic | Sync on every Git commit | Dev/staging, or low-risk services |
| Prune | Delete resources removed from Git | Keep cluster clean |
| Self-heal | Revert manual `kubectl` changes | Prevent configuration drift |

### App of Apps Pattern

For managing many applications across environments, use a parent Application that manages child Applications.

```yaml
# Root app — points to a directory of Application manifests
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-apps
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/my-org/k8s-manifests
    targetRevision: main
    path: argocd/applications/prod   # Contains Application YAML files
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Directory structure:
```
argocd/
  applications/
    prod/
      frontend.yaml         # Application CRD for frontend
      backend.yaml          # Application CRD for backend
      infrastructure.yaml   # Application CRD for cert-manager, ingress, etc.
    staging/
      ...
```

### ArgoCD Image Updater

Automatically updates image tags in Git when new images are pushed to a registry.

```yaml
# Annotation on Application
annotations:
  argocd-image-updater.argoproj.io/image-list: my-app=my-registry/my-app
  argocd-image-updater.argoproj.io/my-app.update-strategy: semver
  argocd-image-updater.argoproj.io/my-app.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
  argocd-image-updater.argoproj.io/write-back-method: git  # Commit new tag to Git
  argocd-image-updater.argoproj.io/git-branch: main
```

### ArgoCD RBAC and Projects

Projects scope which repos and clusters an Application can use, and who can manage it.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-backend
  namespace: argocd
spec:
  description: "Backend team applications"
  sourceRepos:
    - 'https://github.com/my-org/backend-*'
  destinations:
    - namespace: 'backend-*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota   # Teams can't change their own quotas
  roles:
    - name: developer
      description: Can sync and view apps
      policies:
        - p, proj:team-backend:developer, applications, get, team-backend/*, allow
        - p, proj:team-backend:developer, applications, sync, team-backend/*, allow
      groups:
        - my-org:backend-team
```

### ArgoCD CLI

```bash
# Login
argocd login argocd.example.com --sso

# List apps and their sync status
argocd app list

# Check diff between Git and live cluster
argocd app diff my-app

# Sync an app (trigger reconcile)
argocd app sync my-app

# Sync specific resources only
argocd app sync my-app --resource apps:Deployment:my-app

# Rollback to previous revision
argocd app rollback my-app 3

# Get app history
argocd app history my-app
```

---

## Flux CD

Flux takes a more Kubernetes-native approach: every feature is a CRD and controller. More composable, less UI, preferred by platform teams.

### Core CRDs

```yaml
# 1. GitRepository — where to fetch manifests from
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-org-manifests
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/my-org/k8s-manifests
  ref:
    branch: main
  secretRef:
    name: github-credentials  # SSH key or PAT

---
# 2. Kustomization — what to apply and where
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app-prod
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: my-org-manifests
  path: ./apps/my-app/overlays/prod
  prune: true         # Delete removed resources
  wait: true          # Wait for resources to be healthy
  timeout: 5m
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-app
      namespace: production

---
# 3. HelmRelease — deploy a Helm chart via Flux
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: prometheus-stack
  namespace: monitoring
spec:
  interval: 30m
  chart:
    spec:
      chart: kube-prometheus-stack
      version: ">=55.0.0 <60.0.0"
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
  values:
    grafana:
      enabled: true
      adminPassword: ${GRAFANA_ADMIN_PASSWORD}
  valuesFrom:
    - kind: Secret
      name: prometheus-values-override
      valuesKey: values.yaml
      optional: true
```

### Kustomize Overlays Per Environment

```
k8s-manifests/
├── apps/
│   └── my-app/
│       ├── base/
│       │   ├── kustomization.yaml
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       └── overlays/
│           ├── dev/
│           │   ├── kustomization.yaml  # Patches for dev
│           │   └── replica-patch.yaml  # replicas: 1
│           ├── staging/
│           │   ├── kustomization.yaml
│           │   └── replica-patch.yaml  # replicas: 2
│           └── prod/
│               ├── kustomization.yaml
│               └── replica-patch.yaml  # replicas: 5
```

```yaml
# apps/my-app/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml

# apps/my-app/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patches:
  - path: replica-patch.yaml
images:
  - name: my-app
    newTag: v1.5.2    # Updated by image automation
```

### SOPS for Secret Encryption in Git

```bash
# Install SOPS
# Create age key
age-keygen -o age.agekey

# Import key into cluster as secret
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age.agekey

# Encrypt a secret file
sops --age=$(cat age.agekey | grep "public key" | awk '{print $4}') \
     --encrypt --in-place secret.yaml

# Flux Kustomization — tell Flux to decrypt with SOPS
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

### Flux Bootstrap

```bash
# Bootstrap Flux onto a cluster (installs Flux + commits its own manifests to Git)
flux bootstrap github \
  --owner=my-org \
  --repository=k8s-manifests \
  --branch=main \
  --path=clusters/production \
  --personal=false \
  --token-auth
```

---

## Multi-Environment Repository Layout

```
k8s-manifests/                  # Monorepo
├── apps/                       # Application manifests
│   ├── frontend/
│   │   ├── base/
│   │   └── overlays/{dev,staging,prod}/
│   └── backend/
│       ├── base/
│       └── overlays/{dev,staging,prod}/
├── infrastructure/             # Platform components
│   ├── cert-manager/
│   ├── ingress-nginx/
│   ├── monitoring/
│   └── external-secrets/
└── clusters/                   # Flux/ArgoCD entry points per cluster
    ├── dev/
    │   ├── flux-system/
    │   └── apps.yaml           # Points to overlays/dev
    ├── staging/
    └── production/
        ├── flux-system/
        └── apps.yaml           # Points to overlays/prod
```

### Environment Promotion Workflow

```
developer → PR → dev auto-merge → [CI tests pass] → staging PR → [manual approval] → prod PR → merge
```

1. **Dev**: ArgoCD/Flux auto-syncs on every merge to `main`
2. **Staging**: Promotion PR created automatically by CI after dev deploy succeeds
3. **Prod**: Promotion PR requires manual approval from team lead + passing staging smoke tests

---

## Progressive Delivery

### Argo Rollouts (Canary)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 5          # 5% traffic to new version
        - pause: {duration: 10m}
        - setWeight: 25
        - pause: {}             # Manual gate — wait for human approval
        - setWeight: 50
        - pause: {duration: 10m}
        - setWeight: 100
      analysis:
        templates:
          - templateName: success-rate
        startingStep: 2         # Start analysis at step 2
        args:
          - name: service-name
            value: my-app-canary
```

### Flagger + Nginx Canary via GitOps

Flagger automates canary analysis and promotion. Works with Istio, Nginx, Contour.

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: my-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  service:
    port: 80
    targetPort: 8080
  analysis:
    interval: 1m
    threshold: 10       # Max failed checks before rollback
    maxWeight: 50       # Max traffic to canary
    stepWeight: 10      # Increment per step
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 30s
```

---

## Secret Management in GitOps

### Sealed Secrets (Bitnami)

Sealed Secrets encrypts K8s Secrets with a cluster-specific key. Encrypted `SealedSecret` objects are safe to commit to Git.

```bash
# Install kubeseal CLI
# Seal a secret (only the cluster can decrypt)
kubectl create secret generic db-password \
  --from-literal=password=mysecretpassword \
  --dry-run=client -o yaml | \
  kubeseal --format=yaml > db-password-sealed.yaml

# db-password-sealed.yaml is safe to commit to Git
# The controller auto-creates the Secret in the cluster
```

### External Secrets Operator (ESO)

ESO syncs secrets from external providers (AWS Secrets Manager, Vault, GCP Secret Manager) into K8s Secrets.

```yaml
# ExternalSecret — fetch from AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials    # Creates this K8s Secret
    creationPolicy: Owner
  data:
    - secretKey: password   # Key in K8s Secret
      remoteRef:
        key: prod/db         # Secret name in AWS SM
        property: password   # JSON key within the secret

---
# ClusterSecretStore — how to authenticate with AWS SM
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
```

---

## Anti-Patterns

1. **Pushing directly to cluster from CI** — CI systems with cluster credentials are attack vectors. Use pull-based GitOps
2. **One repo for all environments** — mixing dev and prod manifests in the same directory leads to accidental promotions. Use separate overlays or separate repos
3. **Unencrypted secrets in Git** — even private repos can be exposed. Always use Sealed Secrets or ESO
4. **No image tag pinning** — `image: my-app:latest` breaks GitOps (same commit, different behavior). Always pin digest or semver tag
5. **Manual kubectl apply alongside GitOps** — manual changes get reverted by the controller. Educate the team: all changes go through Git
