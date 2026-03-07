---
name: cloud-devops
description: Use when working with Docker, Kubernetes, Terraform, AWS, GCP, Azure, CI/CD, GitHub Actions, GitLab CI, deployment, infrastructure, IaC, Helm, containers, load balancer, autoscaling, monitoring, CloudFormation, CDK, Pulumi, nginx, SSL, DNS, serverless, Lambda, ECS, EKS, GKE, AKS, microservices, Docker Compose, ECR, secrets management, Vault, workflow triggers, matrix builds, artifact caching, ECS Fargate, App Runner, Cloud Run, Cloud Functions, event-driven, cold starts, Lambda Layers, provisioned concurrency, dead letter queue, SQS trigger, step functions, OIDC credentials, cost optimization, reserved instances, spot instances, observability, Prometheus, Grafana, OpenTelemetry, tracing, SLO, SLI, error budget, FinOps, Kubecost, GitOps, ArgoCD, Flux, Kustomize, progressive delivery, OPA, Kyverno, policy-as-code, NetworkPolicy, image scanning, Trivy, SLSA, SBOM, service mesh, Istio, Linkerd, mTLS, canary deployment, CRD, admission webhook, Velero, disaster recovery, etcd backup, vCluster, multi-tenancy, pod affinity.
---

# Cloud & DevOps

Master skill for containerization, orchestration, infrastructure as code, CI/CD pipelines, cloud providers, and serverless architecture. Philosophy: infrastructure should be reproducible, version-controlled, and immutable -- treat servers as cattle, not pets.

## Task Router

| Task | Reference |
|------|-----------|
| Dockerfiles, images, Compose, security | [references/docker.md](references/docker.md) |
| Kubernetes objects, Helm, troubleshooting | [references/kubernetes.md](references/kubernetes.md) |
| Terraform modules, state, workspaces | [references/terraform.md](references/terraform.md) |
| GitHub Actions, GitLab CI, pipelines | [references/cicd.md](references/cicd.md) |
| AWS/GCP/Azure services, architectures | [references/cloud-providers.md](references/cloud-providers.md) |
| Lambda, Cloud Functions, event-driven | [references/serverless.md](references/serverless.md) |
| Prometheus, Grafana, OTel, SLO/SLI, tracing, alerting | [references/observability.md](references/observability.md) |
| FinOps, cost optimization, reserved instances, Kubecost | [references/finops.md](references/finops.md) |
| ArgoCD, Flux, GitOps, progressive delivery, Sealed Secrets | [references/gitops.md](references/gitops.md) |
| OPA, Kyverno, NetworkPolicy, image scanning, SBOM, SLSA | [references/security-policy.md](references/security-policy.md) |
| Istio, Linkerd, mTLS, traffic management, service graph | [references/service-mesh.md](references/service-mesh.md) |
| CRDs, operators, admission webhooks, Velero, DR, vCluster | [references/kubernetes-advanced.md](references/kubernetes-advanced.md) |

## Before Starting

Answer these questions before writing any infrastructure code:

1. **Which cloud provider?** AWS, GCP, Azure, or multi-cloud? Each has different service names and idioms
2. **What orchestrator?** Kubernetes, ECS, Cloud Run, or plain VMs? Determines deployment strategy
3. **Existing infra?** Importing existing resources into Terraform is different from greenfield
4. **IaC tool?** Terraform (multi-cloud), CDK/Pulumi (imperative), CloudFormation (AWS-only)
5. **CI/CD platform?** GitHub Actions, GitLab CI, Jenkins, CircleCI -- each has different syntax
6. **Environment strategy?** How many envs (dev/staging/prod)? How are they separated?

## Quick Reference

### Docker Commands

| Need | Command |
|------|---------|
| Build image | `docker build -t app:v1 .` |
| Run with port | `docker run -p 8080:80 app:v1` |
| Shell into container | `docker exec -it <id> /bin/sh` |
| View logs | `docker logs -f <id>` |
| Prune everything | `docker system prune -a --volumes` |
| Multi-arch build | `docker buildx build --platform linux/amd64,linux/arm64 -t app:v1 .` |

### Kubernetes Commands

| Need | Command |
|------|---------|
| Apply manifest | `kubectl apply -f deployment.yaml` |
| Get pod logs | `kubectl logs -f deploy/app -n namespace` |
| Shell into pod | `kubectl exec -it pod/app -- /bin/sh` |
| Port forward | `kubectl port-forward svc/app 8080:80` |
| Describe resource | `kubectl describe pod/app -n namespace` |
| Watch rollout | `kubectl rollout status deploy/app` |
| Debug failing pod | `kubectl get events --sort-by=.lastTimestamp` |

### Terraform Commands

| Need | Command |
|------|---------|
| Initialize | `terraform init` |
| Preview changes | `terraform plan -out=plan.tfplan` |
| Apply changes | `terraform apply plan.tfplan` |
| Import resource | `terraform import aws_instance.web i-1234567890` |
| Show state | `terraform state list` |
| Destroy all | `terraform destroy` (use with caution) |

## Core Principles

1. **Infrastructure as Code** -- every resource defined in version-controlled files. No manual console clicks. Why: reproducibility, audit trail, code review for infra changes
2. **Immutable infrastructure** -- replace, don't patch. Build new images instead of SSHing in to fix. Why: eliminates configuration drift, makes rollbacks trivial
3. **Least privilege** -- every service account, IAM role, and container runs with minimum permissions. Why: blast radius reduction when (not if) something is compromised
4. **12-Factor App** -- config via env vars, stateless processes, disposable containers. Why: enables horizontal scaling and easy deployment
5. **GitOps** -- git is the single source of truth. Infra changes go through PRs. Why: audit trail, rollback via git revert, consistent environments
6. **Defense in depth** -- network policies + IAM + secrets management + image scanning. Why: no single security layer is sufficient
7. **Observe everything** -- metrics, logs, traces (the three pillars). Alert on symptoms, not causes. Why: you can't fix what you can't see

## Decision Trees

### Containers vs Serverless

```
Need persistent connections (WebSocket, gRPC)?
  YES → Containers (ECS/K8s/Cloud Run)
  NO → How long do requests take?
    > 15 minutes → Containers
    < 15 minutes → How much traffic?
      Spiky/unpredictable → Serverless (Lambda/Cloud Functions)
      Steady high volume → Containers (cheaper at scale)
      Very low → Serverless (pay per invocation)
```

### Kubernetes vs ECS vs Cloud Run

```
Multi-cloud or vendor-agnostic required?
  YES → Kubernetes (EKS/GKE/AKS)
  NO → AWS-only?
    YES → How complex is the workload?
      Simple HTTP services → App Runner or ECS Fargate
      Complex orchestration, service mesh → EKS
    NO → GCP?
      Simple HTTP/gRPC → Cloud Run (easiest option)
      Complex orchestration → GKE
```

### Terraform vs CDK vs Pulumi

```
Multi-cloud?
  YES → Terraform (widest provider support) or Pulumi
  NO → Team prefers HCL (declarative)?
    YES → Terraform
    NO → Team prefers TypeScript/Python (imperative)?
      YES → CDK (AWS-only) or Pulumi (multi-cloud)
```

## Anti-Patterns

1. **Hardcoding secrets** -- never put credentials in Dockerfiles, manifests, or Terraform files. Use secrets managers (Vault, AWS Secrets Manager, K8s Secrets with external-secrets-operator)
2. **Running as root** -- containers should use non-root users. Add `USER nonroot` in Dockerfile
3. **Using `latest` tag** -- always pin image versions. `latest` breaks reproducibility and makes rollbacks impossible
4. **Monolithic Terraform state** -- split state per environment and per service. Large state files are slow and risky
5. **No health checks** -- every container needs liveness and readiness probes. Without them, K8s routes traffic to broken pods
6. **Ignoring resource limits** -- set CPU/memory requests AND limits. Without them, one pod can starve the entire node
7. **Manual deployments** -- if you SSH into prod to deploy, you've already lost. Automate everything through CI/CD
8. **Storing state locally** -- Terraform state belongs in a remote backend (S3, GCS) with locking (DynamoDB). Local state causes conflicts
9. **No network policies** -- default K8s allows all pod-to-pod traffic. Define explicit NetworkPolicies
10. **Skipping staging** -- deploy to staging first, always. "It works on my machine" is not a deployment strategy
