---
name: cloud-infra
description: Use when working with Docker, Kubernetes, Terraform, CI/CD, cloud providers (AWS/GCP/Azure), serverless, observability, bash/shell scripts (getopts, strict mode, traps), systemd, or infrastructure tooling. Also covers Helm, GitHub Actions, GitLab CI, Lambda, Cloud Run, ECS, EKS, GKE, nginx, DNS, SSL, Prometheus, Grafana, OpenTelemetry, FinOps, GitOps, ArgoCD, service mesh, Istio, BATS testing, ShellCheck, cron, awk, sed, curl, parallel execution, signal handling, process management.
---

# Cloud Infrastructure & Shell Tooling

Unified skill for cloud infrastructure, DevOps, and shell scripting. Infrastructure should be reproducible, version-controlled, and immutable. Shell scripts are infrastructure glue -- they deserve the same rigor as application code.

## Task Router

### Cloud & DevOps

| Task | Reference |
|------|-----------|
| Dockerfiles, images, Compose, container security | [references/docker.md](references/docker.md) |
| Kubernetes objects, Helm, troubleshooting | [references/kubernetes.md](references/kubernetes.md) |
| CRDs, operators, admission webhooks, Velero, DR, vCluster | [references/kubernetes-advanced.md](references/kubernetes-advanced.md) |
| Terraform modules, state, workspaces | [references/terraform.md](references/terraform.md) |
| GitHub Actions, GitLab CI, pipelines | [references/cicd.md](references/cicd.md) |
| AWS/GCP/Azure services, architectures | [references/cloud-providers.md](references/cloud-providers.md) |
| Lambda, Cloud Functions, event-driven | [references/serverless.md](references/serverless.md) |
| Prometheus, Grafana, OTel, SLO/SLI, tracing | [references/observability.md](references/observability.md) |
| FinOps, cost optimization, reserved instances | [references/finops.md](references/finops.md) |
| ArgoCD, Flux, GitOps, progressive delivery | [references/gitops.md](references/gitops.md) |
| OPA, Kyverno, NetworkPolicy, image scanning, SBOM | [references/security-policy.md](references/security-policy.md) |
| Istio, Linkerd, mTLS, traffic management | [references/service-mesh.md](references/service-mesh.md) |

### Shell Scripting

| Task | Reference |
|------|-----------|
| Defensive patterns, traps, strict mode, atomicity | [references/defensive.md](references/defensive.md) |
| BATS testing, mocking, fixtures | [references/bats-testing.md](references/bats-testing.md) |
| ShellCheck config and suppression | [references/shellcheck.md](references/shellcheck.md) |
| Argument parsing (getopts, getopt, subcommands) | [references/argument-parsing.md](references/argument-parsing.md) |
| systemd services and timers | [references/systemd-services.md](references/systemd-services.md) |
| Text processing (awk, sed, pipelines) | [references/text-processing.md](references/text-processing.md) |
| Production logging (structured, JSON, syslog) | [references/logging-production.md](references/logging-production.md) |
| HTTP/networking (curl, wget, retry, APIs) | [references/http-networking.md](references/http-networking.md) |
| Parallel execution (xargs, GNU parallel, pools) | [references/parallel-execution.md](references/parallel-execution.md) |
| Advanced debugging (PS4, BASH_XTRACEFD, traps) | [references/debugging-advanced.md](references/debugging-advanced.md) |

## Core Principles

1. **Infrastructure as Code** -- every resource in version-controlled files, no manual console clicks
2. **Immutable infrastructure** -- replace, don't patch; build new images instead of SSHing in
3. **Least privilege** -- minimum permissions for every service account, IAM role, container
4. **Strict shell mode** -- every script starts with `set -Eeuo pipefail`, quotes all variables
5. **Observe everything** -- metrics, logs, traces; alert on symptoms, not causes
6. **GitOps** -- git is single source of truth; infra changes go through PRs
7. **Test shell scripts** -- BATS makes it easy; run ShellCheck in CI as pre-commit hook

## Layer 3 Skills

- **deploy-vercel** — Vercel deployment and configuration
- **deploy-modal** — Modal serverless GPU deployment
- **deploy-convex** — Convex backend deployment
- **monitoring-sentry** — Sentry error monitoring and alerting
- **testing-quality** — BATS shell testing, CI/CD test pipelines
