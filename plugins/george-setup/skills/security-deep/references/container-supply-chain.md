# Container Security & Software Supply Chain Reference

---

## Container Hardening

### Distroless Images

Distroless images contain only your application and its runtime dependencies — no shell, package manager, or utilities. This dramatically reduces attack surface.

```dockerfile
# Multi-stage: build with full image, run with distroless
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
COPY src/ src/

# Distroless runtime — no shell, no apt, minimal attack surface
FROM gcr.io/distroless/python3-debian12:nonroot
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --from=builder /app/src /app/src
# Note: no ENTRYPOINT shell — uses exec form
CMD ["src/main.py"]
```

```dockerfile
# Node.js distroless
FROM node:20-slim AS builder
WORKDIR /app
COPY package*.json .
RUN npm ci --only=production

FROM gcr.io/distroless/nodejs20-debian12:nonroot
WORKDIR /app
COPY --from=builder /app/node_modules node_modules
COPY src/ src/
CMD ["src/server.js"]
```

---

### Rootless Containers

```dockerfile
# Create non-root user explicitly
FROM python:3.12-slim
RUN groupadd -r appgroup && useradd -r -g appgroup -u 1001 appuser
WORKDIR /app
COPY --chown=appuser:appgroup . .
RUN pip install --no-cache-dir -r requirements.txt
USER appuser  # switch to non-root before CMD
EXPOSE 8080
CMD ["python", "src/main.py"]
```

```yaml
# Kubernetes — enforce non-root at pod level
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: myapp:latest
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]  # drop all Linux capabilities
          add: ["NET_BIND_SERVICE"]  # add only if needed (port < 1024)
      volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: varrun
          mountPath: /var/run
  volumes:
    - name: tmp
      emptyDir: {}
    - name: varrun
      emptyDir: {}
```

---

### Read-Only Filesystem

```dockerfile
# Dockerfile — identify writable paths your app needs
# Then mount them as tmpfs or volumes at runtime
```

```bash
# Run with read-only FS; mount tmp explicitly
docker run \
  --read-only \
  --tmpfs /tmp:size=100m \
  --tmpfs /var/run:size=10m \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --user 1001:1001 \
  myapp:latest
```

---

### Capability Dropping

```bash
# Default Docker capabilities to always drop:
# NET_RAW, SYS_ADMIN, SYS_PTRACE, SYS_MODULE, DAC_READ_SEARCH
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp:latest

# Verify running container capabilities
docker inspect <id> | jq '.[].HostConfig.CapAdd, .[].HostConfig.CapDrop'
```

---

## Image Scanning

### Trivy
```bash
# Scan for CVEs + secrets + misconfigs
trivy image --severity HIGH,CRITICAL myapp:latest

# Scan with exit code (CI gate)
trivy image --exit-code 1 --severity CRITICAL myapp:latest

# Scan Dockerfile (IaC)
trivy config Dockerfile

# Scan all images in a Kubernetes cluster
trivy k8s --report=summary cluster

# Output formats
trivy image --format json myapp:latest | jq '.Results[].Vulnerabilities | length'
trivy image --format sarif myapp:latest > trivy.sarif
```

### Grype
```bash
# Install
brew install anchore/grype/grype

# Scan image
grype myapp:latest --fail-on critical

# Scan against SBOM
grype sbom:./sbom.spdx.json

# CI integration
grype myapp:${{ github.sha }} -o sarif > grype.sarif
```

### GitHub Actions — Container Scan Pipeline
```yaml
- name: Build image
  run: docker build -t ${{ env.IMAGE_TAG }} .

- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_TAG }}
    format: sarif
    output: trivy-results.sarif
    severity: CRITICAL,HIGH
    exit-code: 1

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: trivy-results.sarif
```

---

## Cosign & Sigstore — Image Signing

```bash
# Install cosign
brew install cosign

# Generate key pair (for non-keyless signing)
cosign generate-key-pair

# Sign image (keyless — uses OIDC, no key management)
cosign sign --yes myregistry.io/myapp:v1.0.0

# Sign with key pair
cosign sign --key cosign.key myregistry.io/myapp:v1.0.0

# Verify
cosign verify \
  --certificate-identity-regexp "https://github.com/myorg/myrepo/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  myregistry.io/myapp:v1.0.0

# GitHub Actions — keyless signing in CI
- name: Sign image
  run: |
    cosign sign --yes ${{ env.IMAGE }}@${{ steps.build.outputs.digest }}
  env:
    COSIGN_EXPERIMENTAL: "true"
```

### Enforce image signing in Kubernetes (Policy Controller)
```yaml
# Sigstore Policy Controller — require signed images
apiVersion: policy.sigstore.dev/v1alpha1
kind: ClusterImagePolicy
metadata:
  name: require-signed-images
spec:
  images:
    - glob: "myregistry.io/**"
  authorities:
    - keyless:
        url: https://fulcio.sigstore.dev
        identities:
          - issuer: https://token.actions.githubusercontent.com
            subjectRegExp: "https://github.com/myorg/.*"
```

---

## SLSA — Supply Chain Levels for Software Artifacts

| Level | Requirements | What it prevents |
|-------|-------------|-----------------|
| SLSA 1 | Scripted build + provenance | Typos, mistakes |
| SLSA 2 | Version controlled + signed provenance | Source tampering |
| SLSA 3 | Isolated build + non-falsifiable provenance | Build tampering |
| SLSA 4 | Two-party review + hermetic build | Insider threats |

```yaml
# GitHub Actions — SLSA 3 provenance with slsa-github-generator
jobs:
  build:
    outputs:
      digests: ${{ steps.hash.outputs.digests }}
    steps:
      - uses: actions/checkout@v4
      - name: Build artifact
        run: make build && sha256sum artifact > checksums.txt
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: artifact
          path: artifact

  provenance:
    needs: [build]
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.0.0
    with:
      base64-subjects: "${{ needs.build.outputs.digests }}"
    permissions:
      actions: read
      id-token: write
      contents: write
```

---

## SBOM — Software Bill of Materials

```bash
# Generate SBOM with syft
brew install syft

# From container image
syft myapp:latest -o spdx-json > sbom.spdx.json
syft myapp:latest -o cyclonedx-json > sbom.cdx.json

# From directory
syft dir:./src -o spdx-json > sbom.spdx.json

# Scan SBOM for vulnerabilities with grype
grype sbom:./sbom.spdx.json

# Attest SBOM to image (combines with Cosign)
syft attest --output spdx-json myregistry.io/myapp:v1.0.0 | \
  cosign attest --predicate - --type spdxjson \
  myregistry.io/myapp:v1.0.0

# Verify SBOM attestation
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  myregistry.io/myapp:v1.0.0
```

---

## Dependency Confusion & Typosquatting

### Dependency Confusion Attack
Attacker publishes a public npm/pypi package with the same name as your internal private package. Package manager fetches the public (attacker) version.

```bash
# npm — pin internal packages to private registry
# .npmrc
@myorg:registry=https://registry.mycompany.com/
//registry.mycompany.com/:_authToken=${NPM_REGISTRY_TOKEN}

# Or use npm config scopes
npm config set @myorg:registry https://registry.mycompany.com/

# pip — use --index-url to force private registry for internal packages
# pip.conf
[global]
index-url = https://pypi.org/simple/
extra-index-url = https://registry.mycompany.com/simple/

# Better: use --no-index with explicit index for internal-only packages
```

### Typosquatting Detection
```bash
# pypi-audit-hook — checks new packages against known-typosquatted list
pip install pypi-audit-hook

# npm — use Socket Security
npx @socket.dev/npm-package-check

# CI: compare resolved package names against known-good manifest
# Alert if unexpected package names appear in lock files
```

---

## Dockerfile Security Linting — hadolint

```bash
# Install
brew install hadolint

# Lint Dockerfile
hadolint Dockerfile

# Common rules:
# DL3006 — pin image tags (FROM ubuntu:20.04 not ubuntu:latest)
# DL3008 — pin apt package versions
# DL3009 — delete apt lists after install (reduce image size + prevent stale data)
# DL3013 — pin pip packages
# DL3020 — COPY preferred over ADD (less surprising)
# DL4001 — use SHELL or exec-form CMD

# CI
- name: Lint Dockerfile
  uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: Dockerfile
    failure-threshold: warning
```

---

## Private Registry Security

```bash
# ECR — image scanning on push
aws ecr put-image-scanning-configuration \
  --repository-name myapp \
  --image-scanning-configuration scanOnPush=true

# ECR — lifecycle policy (expire old images)
aws ecr put-lifecycle-policy \
  --repository-name myapp \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep last 30 images",
      "selection": {"tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 30},
      "action": {"type": "expire"}
    }]
  }'

# Pull-through cache with immutable tags
aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix "docker-hub" \
  --upstream-registry-url "registry-1.docker.io"
```

---

## Supply Chain Security Checklist

- [ ] Distroless or minimal base image (no unnecessary tools)
- [ ] Non-root user in container (USER directive)
- [ ] Read-only root filesystem with explicit writable mounts
- [ ] All capabilities dropped; only necessary ones re-added
- [ ] Container image scanned: Trivy or Grype in CI (fail on Critical)
- [ ] Images signed with Cosign/Sigstore (keyless in CI)
- [ ] SBOM generated and attached to each release artifact
- [ ] SLSA provenance generated for releases
- [ ] Dockerfile linted with hadolint
- [ ] Dependency confusion: internal packages pinned to private registry
- [ ] Typosquatting protection: lock files committed and verified
- [ ] Base image updated regularly (Dependabot for Dockerfiles)
- [ ] Private registry: scan on push enabled; lifecycle policies set
- [ ] Kubernetes: non-root enforcement via PodSecurity or OPA Gatekeeper
