# FinOps — Cloud Cost Optimization

FinOps is the practice of bringing financial accountability to the variable spend model of cloud. It's not just cutting costs — it's enabling engineering teams to make better cost-conscious decisions while moving fast.

## FinOps Culture & Team Structure

### The Three-Team Model

| Team | Role |
|------|------|
| Engineering | Implement optimizations, rightsize resources, build cost-efficient architectures |
| Finance | Budget ownership, showback/chargeback, variance analysis |
| Business/Product | Trade-off decisions (performance vs cost), feature cost awareness |

The FinOps team acts as a center of excellence that enables each group rather than owning cost centrally.

### Crawl / Walk / Run Maturity Model

**Crawl** (getting visibility):
- Enable cost visibility per team/project/environment
- Implement tagging strategy
- Set up budget alerts (email when 80% consumed)
- Basic reporting: monthly cost by service

**Walk** (optimization):
- Rightsize top 20 over-provisioned resources
- Purchase Reserved Instances or Savings Plans for stable workloads
- Implement Spot for dev/batch workloads
- Showback: "Your team spent $12,400 last month"

**Run** (continuous optimization):
- Automated rightsizing recommendations with auto-apply
- Chargeback: costs allocated to P&L per team
- Anomaly detection with auto-remediation
- Cost as a feature requirement in sprint planning
- Unit economics: cost per API call, cost per user, cost per transaction

---

## Tagging Strategy for Cost Allocation

Consistent tagging is the foundation of all cost attribution. Without tags, costs are unallocable.

### Mandatory Tag Schema

```
team:       engineering / data / platform / security
env:        production / staging / development / sandbox
service:    checkout / payments / user-service / data-pipeline
owner:      user@company.com (for accountability)
cost-center: CC-1234 (finance integration)
project:    project-name or JIRA epic
```

### Enforcement

- Terraform: `default_tags` in provider block enforces on all AWS resources
- Kubernetes: namespace labels for cost attribution
- Policy-as-code: OPA/Kyverno reject untagged resources

```hcl
# Terraform — enforce tags on all resources
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      team        = var.team
      env         = var.environment
      service     = var.service_name
      owner       = var.owner_email
      cost-center = var.cost_center
      managed-by  = "terraform"
    }
  }
}
```

---

## Cloud Cost Optimization Tactics

### Right-Sizing: CPU/Memory Utilization Analysis

Most over-provisioning happens at 2-3x actual usage. Analysis approach:

1. Pull 14-30 day P95 CPU and memory metrics per instance/pod
2. Compare to provisioned size
3. Identify instances using < 20% of provisioned resources
4. Downsize to next smaller instance type (always test in staging first)

```bash
# AWS: CloudWatch metrics for rightsizing
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-31T00:00:00Z \
  --period 86400 \
  --statistics Average,p95

# Tools: AWS Compute Optimizer, GCP Recommender, Azure Advisor
# all provide automated rightsizing recommendations
```

### Reserved Instances vs Savings Plans vs On-Demand vs Spot

```
Is this workload predictable and long-lived (1+ year)?
  YES → Savings Plans or Reserved Instances
    Is the instance family/type fixed (e.g., always m5.xlarge)?
      YES → Reserved Instances (deeper discount, less flexibility)
      NO  → Savings Plans (more flexible, applies to any compute)
  NO → Is it fault-tolerant and stateless?
    YES → Spot Instances (60-90% savings, can be interrupted)
    NO  → On-Demand (no commitment, pay per second)
```

| Type | Discount vs On-Demand | Commitment | Flexibility |
|------|-----------------------|------------|-------------|
| On-Demand | 0% | None | Full |
| Savings Plans (1yr) | ~30-40% | 1 year, $/hr spend | Any instance family |
| Savings Plans (3yr) | ~50-60% | 3 year, $/hr spend | Any instance family |
| Reserved Instance (1yr) | ~35-45% | 1 year, specific type | Fixed family/region |
| Reserved Instance (3yr) | ~55-65% | 3 year | Fixed family/region |
| Spot | 60-90% | None | Can be interrupted with 2min notice |

### Spot Interruption Handling

Spot instances get a 2-minute warning before termination. Graceful shutdown pattern:

```bash
#!/bin/bash
# Poll IMDS for termination notice (runs every 5s in a sidecar)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

while true; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/spot/termination-time")
  if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Spot termination notice received — draining..."
    # Drain from load balancer, flush queues, save state
    drain_gracefully
    exit 0
  fi
  sleep 5
done
```

### GCP Committed Use Discounts

- **Resource-based CUDs**: Commit to specific vCPUs/memory in a region for 1 or 3 years (~37-55% discount)
- **Spend-based CUDs**: Commit to a spend amount on Cloud Run, GKE, etc. (~17-25%)
- **Preemptible VMs**: ~80% discount, 24h max lifespan, 30s shutdown notice

### Azure Reserved VM Instances

- 1-year: ~36% discount, 3-year: ~52% discount
- Scope: Subscription or resource group
- Can exchange or cancel (with penalty) — more flexible than AWS RI

---

## Kubernetes Cost Efficiency

### Vertical Pod Autoscaler (VPA)

VPA recommends (or auto-applies) CPU/memory requests based on actual usage.

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"   # "Off"=recommend only, "Initial"=set on creation, "Auto"=evict+update
  resourcePolicy:
    containerPolicies:
      - containerName: app
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 4
          memory: 4Gi
        controlledResources: ["cpu", "memory"]
```

Warning: VPA and HPA conflict when both target CPU. Use VPA for memory + HPA for CPU, or use KEDA for custom metrics.

### Bin Packing: Requests vs Limits

The scheduler uses *requests* for placement, nodes consume up to *limits*. Inefficiency sources:

- **Requests too high**: Scheduler sees node as full even when CPU/memory is idle. Reduce requests to P95 actual usage.
- **Limits too low**: OOMKill or CPU throttle at peak. Set limits to ~2-3x requests.
- **No limits set**: A runaway pod starves the node. Always set limits.

```yaml
resources:
  requests:
    cpu: 250m       # Scheduler uses this — set to P95 actual
    memory: 256Mi   # Set to P99 actual
  limits:
    cpu: 1000m      # Burst headroom
    memory: 512Mi   # OOM if exceeded — be conservative
```

### Spot Node Pools for Non-Critical Workloads

```yaml
# EKS managed node group — spot
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
managedNodeGroups:
  - name: spot-workers
    instanceTypes: ["m5.xlarge", "m5a.xlarge", "m4.xlarge"]  # Multiple types = less interruption
    spot: true
    minSize: 0
    maxSize: 20
    labels:
      node-type: spot
      workload: batch
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule

# Pod tolerates spot taint + prefers spot nodes
spec:
  tolerations:
    - key: spot
      operator: Equal
      value: "true"
      effect: NoSchedule
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
              - key: node-type
                operator: In
                values: [spot]
```

### Namespace Resource Quotas for Chargeback

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-budget
  namespace: team-backend
spec:
  hard:
    requests.cpu: "16"
    requests.memory: 32Gi
    limits.cpu: "32"
    limits.memory: 64Gi
    pods: "50"
    services.loadbalancers: "2"    # Load balancers are expensive
    persistentvolumeclaims: "10"
```

---

## Cost Attribution

### Kubecost / OpenCost

Both tools break down K8s costs by namespace, deployment, pod, and label.

```bash
# Install OpenCost (open-source K8s cost tool)
helm install opencost opencost/opencost \
  --namespace opencost --create-namespace \
  --set opencost.exporter.cloudProviderApiKey="<AWS_PRICING_API_KEY>"

# Query cost by namespace (REST API)
curl "http://opencost:9003/allocation/compute?window=7d&aggregate=namespace"
```

### Showback vs Chargeback

| Model | Description | Maturity |
|-------|-------------|----------|
| Showback | Teams *see* their costs, no financial transfer | Crawl/Walk |
| Chargeback | Costs *transferred* to team budgets (real money) | Run |

Showback builds awareness. Chargeback drives behavior change. Start with showback for 3-6 months.

---

## Tooling Reference

### AWS

```bash
# Cost Explorer CLI
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=TAG,Key=service

# Trusted Advisor — rightsizing
aws support describe-trusted-advisor-check-result \
  --check-id "Qch7DwouX1"  # Low Utilization Amazon EC2 Instances
```

### Infracost (Terraform cost estimation in CI)

```yaml
# .github/workflows/infracost.yml
- name: Run Infracost
  uses: infracost/actions/setup@v2
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate Infracost diff
  run: |
    infracost diff \
      --path=. \
      --format=json \
      --compare-to=infracost-base.json \
      --out-file=infracost-diff.json

- name: Post PR comment
  uses: infracost/actions/comment@v2
  with:
    path: infracost-diff.json
    behavior: update   # Update existing comment on re-run
```

### Azure Cost Management

```bash
# Azure CLI — cost by resource group
az consumption usage list \
  --start-date 2025-01-01 \
  --end-date 2025-01-31 \
  --query "[].{ResourceGroup:resourceGroup, Cost:pretaxCost, Currency:currency}"
```

---

## Anomaly Detection & Budget Alerts

### AWS Budget Alert

```hcl
# Terraform — AWS budget with SNS alert
resource "aws_budgets_budget" "monthly" {
  name         = "monthly-cost-budget"
  budget_type  = "COST"
  limit_amount = "10000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["team$engineering"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["finops@company.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["finops@company.com", "engineering-lead@company.com"]
  }
}
```

### Cost Spike Investigation Workflow

1. **Detect**: Budget alert fires or anomaly detected in Cost Explorer
2. **Identify**: Filter by service and time to isolate the spike
3. **Tag hunt**: Find untagged resources (often new resources without tags)
4. **Root cause**: NAT Gateway data transfer? Forgotten dev instance? S3 egress? New feature?
5. **Fix**: Rightsize/delete, add tagging enforcement, add budget controls
6. **Post-mortem**: Document to prevent recurrence, update tagging policy

```bash
# Find untagged EC2 instances
aws resourcegroupstaggingapi get-resources \
  --resource-type-filters ec2:instance \
  --tag-filters Key=env \
  --query "ResourceTagMappingList[?Tags==\`[]\`].ResourceARN"
```

---

## Anti-Patterns

1. **Buying RIs/Savings Plans without baseline** — commit only after 2+ months of stable usage data. Unused RIs still cost money
2. **Tagging after the fact** — retroactive tagging is painful. Enforce from day one via IaC and policy
3. **Optimizing dev/staging aggressively** — dev environments should be cheap but not at the cost of engineering time. Auto-shutoff schedules > manual management
4. **Single-family Reserved Instances for variable workloads** — Savings Plans are more flexible. RIs are only worth it for truly fixed instance types
5. **No cost visibility for engineers** — hiding costs from engineers removes the incentive to optimize. Show team dashboards in Slack weekly
