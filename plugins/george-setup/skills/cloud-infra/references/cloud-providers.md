# Cloud Providers Reference

## Decision Matrix

| Use Case | AWS | GCP | Azure |
|----------|-----|-----|-------|
| Simple HTTP container | App Runner / ECS Fargate | Cloud Run | App Service / Container Apps |
| Kubernetes | EKS | GKE (best managed K8s) | AKS |
| Serverless functions | Lambda | Cloud Functions | Azure Functions |
| Static site + CDN | S3 + CloudFront | Cloud Storage + Cloud CDN | Azure Blob + Azure CDN |
| Managed PostgreSQL | RDS / Aurora | Cloud SQL | Azure Database for PostgreSQL |
| NoSQL / document store | DynamoDB | Firestore | Cosmos DB |
| Message queue | SQS | Pub/Sub | Service Bus |
| Container registry | ECR | Artifact Registry | Azure Container Registry |
| Secrets management | Secrets Manager / Parameter Store | Secret Manager | Key Vault |
| CI/CD | CodePipeline + CodeBuild | Cloud Build + Cloud Deploy | Azure Pipelines |
| Monitoring + logs | CloudWatch + X-Ray | Cloud Logging + Cloud Trace | Azure Monitor + App Insights |
| ML/AI workloads | SageMaker | Vertex AI | Azure ML |
| Microsoft ecosystem | Poor fit | Poor fit | Best fit (AAD, Office 365) |
| Multi-cloud Kubernetes | EKS anywhere | GKE multi-cloud | Azure Arc |

**Choosing a provider**: Default to AWS for broadest service selection and community. Choose GCP when running K8s (GKE is the gold standard) or using Google ML APIs. Choose Azure when the organization already uses Microsoft products (Active Directory, Office 365, Visual Studio).

---

## AWS

### Compute

**ECS Fargate** — serverless container execution. No cluster node management. Ideal for most containerized web services.

```hcl
# Terraform: ECS Fargate service
resource "aws_ecs_task_definition" "app" {
  family                   = "myapp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512    # 0.5 vCPU
  memory                   = 1024   # 1 GB

  container_definitions = jsonencode([{
    name      = "myapp"
    image     = "${var.ecr_url}:${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    environment = [
      { name = "NODE_ENV", value = "production" }
    ]
    secrets = [
      { name = "DATABASE_URL", valueFrom = aws_ssm_parameter.db_url.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/myapp"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
}

resource "aws_ecs_service" "app" {
  name            = "myapp"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "myapp"
    container_port   = 8080
  }
}
```

**EKS** — managed Kubernetes. Use when you need K8s ecosystem (Helm charts, operators, service mesh) or multi-cloud portability.

**Lambda** — see serverless.md for full reference.

**App Runner** — simplest AWS option. Point at ECR image or source code; AWS handles everything. No task definitions, no clusters. Best for: small teams, simple HTTP services, fast time-to-deploy.

**EC2** — use only when you need specific hardware, persistent GPU workloads, or can't containerize. Avoid for typical web services; Fargate is almost always better.

### Networking

**VPC structure** — always use multiple availability zones. Standard setup:

```
VPC (10.0.0.0/16)
├── Public subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
│   └── Load balancer, NAT Gateway, bastion (if needed)
└── Private subnets (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)
    └── Application containers, databases
```

```hcl
# Security group: ALB allows inbound 443 from internet
resource "aws_security_group" "alb" {
  name   = "alb"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group: app only allows traffic from ALB
resource "aws_security_group" "app" {
  name   = "app"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
}
```

**ALB vs NLB**: Use ALB (Layer 7) for HTTP/HTTPS with path/host routing, sticky sessions, WAF integration. Use NLB (Layer 4) for ultra-low latency, non-HTTP protocols, or when you need static IPs.

**CloudFront**: CDN for static assets and API caching. Configure with S3 origin for static sites. Use OAC (Origin Access Control) instead of deprecated OAI to restrict S3 access to CloudFront only.

### Deployment

**CloudFormation**: AWS-native IaC. Verbose JSON/YAML. Prefer Terraform for multi-cloud or CDK for teams preferring imperative code.

**CDK** (Cloud Development Kit): Define AWS infra in TypeScript/Python/Java. Compiles to CloudFormation. Best when team prefers code over HCL.

```typescript
// CDK example: ECS Fargate service
const service = new ecs_patterns.ApplicationLoadBalancedFargateService(this, 'Service', {
  cluster,
  taskImageOptions: {
    image: ecs.ContainerImage.fromEcrRepository(repo, imageTag),
    environment: { NODE_ENV: 'production' },
    secrets: { DATABASE_URL: ecs.Secret.fromSsmParameter(dbUrlParam) },
  },
  desiredCount: 2,
  cpu: 512,
  memoryLimitMiB: 1024,
  publicLoadBalancer: true,
});
```

**CodePipeline + CodeBuild**: AWS-native CI/CD. Often more complex to configure than GitHub Actions for the same result. Consider GitHub Actions + OIDC for simpler pipelines.

### Storage and Databases

| Service | Use for | Notes |
|---------|---------|-------|
| S3 | Static assets, backups, Terraform state | Enable versioning + lifecycle rules |
| ECR | Docker images | Scan on push; set lifecycle policy to delete old images |
| RDS (Postgres/MySQL) | Relational data | Multi-AZ for production; use Aurora for auto-scaling |
| DynamoDB | Key-value, high-throughput | On-demand capacity avoids capacity planning |
| ElastiCache | Redis/Memcached caching | Redis cluster mode for HA |

### Secrets Management

**AWS Secrets Manager** — for secrets that rotate (DB passwords, API keys). Supports automatic rotation via Lambda. ~$0.40/secret/month.

```bash
# Store a secret
aws secretsmanager create-secret \
  --name prod/myapp/database \
  --secret-string '{"username":"admin","password":"s3cr3t"}'

# Read in application
aws secretsmanager get-secret-value \
  --secret-id prod/myapp/database \
  --query SecretString --output text | jq .
```

**SSM Parameter Store** — for configuration and non-rotating secrets. Free for standard parameters. SecureString parameters encrypted with KMS. Use `/env/app/key` naming convention.

```hcl
resource "aws_ssm_parameter" "db_url" {
  name  = "/prod/myapp/database-url"
  type  = "SecureString"
  value = var.database_url
  tier  = "Standard"
}
```

### IAM Patterns

**Least privilege**: grant only what's needed. Start with `Deny *`, add specific `Allow` statements.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::myapp-uploads/*"
    },
    {
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/myapp/*"
    }
  ]
}
```

**OIDC for GitHub Actions** (no long-lived credentials):

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:*"
        }
      }
    }]
  })
}
```

### Monitoring: CloudWatch

```bash
# View logs (last 1 hour)
aws logs tail /ecs/myapp --since 1h --follow

# Create metric alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "HighErrorRate" \
  --metric-name "5XXError" \
  --namespace "AWS/ApplicationELB" \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --period 60 \
  --statistic Sum \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:alerts
```

### Cost Optimization (AWS)

- **Use Savings Plans** for steady-state workloads (1-3 year commitment, 40-72% savings vs on-demand)
- **Spot Instances** for batch jobs and fault-tolerant workloads (up to 90% savings)
- **S3 Intelligent-Tiering** for objects with unpredictable access patterns
- **Right-size instances**: use CloudWatch metrics to find over-provisioned resources
- **ECR lifecycle policies**: delete untagged images and keep only last N tagged images
- **NAT Gateway costs money per GB**: batch API calls, use VPC endpoints for AWS services (S3, DynamoDB, SSM) to avoid NAT charges

---

## GCP

### Compute

**Cloud Run** — best serverless container platform. Automatic scaling to zero, pay per request. Simpler than Lambda (full container, not functions). Ideal for HTTP services.

```yaml
# cloud-run-service.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: myapp
  annotations:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/maxScale: "10"
        autoscaling.knative.dev/minScale: "1"  # Keep warm instance
        run.googleapis.com/cpu-throttling: "false"  # Always-on CPU
    spec:
      serviceAccountName: myapp-sa@project.iam.gserviceaccount.com
      containers:
        - image: us-central1-docker.pkg.dev/project/repo/myapp:v1
          resources:
            limits:
              cpu: "1"
              memory: 512Mi
          env:
            - name: NODE_ENV
              value: production
          ports:
            - containerPort: 8080
```

```bash
# Deploy
gcloud run deploy myapp \
  --image us-central1-docker.pkg.dev/project/repo/myapp:v1 \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --min-instances 1
```

**GKE** (Google Kubernetes Engine) — best-managed Kubernetes. Autopilot mode removes node management entirely; standard mode gives full control. GKE has the most mature K8s control plane.

```bash
# Create Autopilot cluster (recommended)
gcloud container clusters create-auto mycluster \
  --region us-central1

# Get credentials
gcloud container clusters get-credentials mycluster --region us-central1
```

**Cloud Functions** — see serverless.md for full reference.

**Compute Engine** — GCP's VMs. Use preemptible/spot VMs for batch workloads (up to 91% savings).

### Deployment

**Cloud Build** — GCP CI/CD. Triggered by Cloud Source Repositories, GitHub, or Bitbucket.

```yaml
# cloudbuild.yaml
steps:
  - name: node:20-alpine
    entrypoint: npm
    args: [ci]

  - name: node:20-alpine
    entrypoint: npm
    args: [test]

  - name: gcr.io/cloud-builders/docker
    args: [build, -t, "us-central1-docker.pkg.dev/$PROJECT_ID/repo/myapp:$SHORT_SHA", .]

  - name: gcr.io/cloud-builders/docker
    args: [push, "us-central1-docker.pkg.dev/$PROJECT_ID/repo/myapp:$SHORT_SHA"]

  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    entrypoint: gcloud
    args:
      - run
      - deploy
      - myapp
      - --image=us-central1-docker.pkg.dev/$PROJECT_ID/repo/myapp:$SHORT_SHA
      - --region=us-central1

images:
  - "us-central1-docker.pkg.dev/$PROJECT_ID/repo/myapp:$SHORT_SHA"
```

**Cloud Deploy** — managed delivery pipeline with promotion and approval gates between environments.

### IAM (GCP)

GCP uses roles (primitive, predefined, custom) assigned to members on resources.

```bash
# Grant Cloud Run invoker to service account
gcloud run services add-iam-policy-binding myapp \
  --region us-central1 \
  --member serviceAccount:caller@project.iam.gserviceaccount.com \
  --role roles/run.invoker

# Workload Identity for GKE (no service account keys)
gcloud iam service-accounts add-iam-policy-binding \
  app-sa@project.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:project.svc.id.goog[namespace/ksa-name]"
```

### Monitoring (GCP)

```bash
# Stream Cloud Run logs
gcloud run services logs tail myapp --region us-central1

# Query logs with filter
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit 50 \
  --format json
```

### Cost Optimization (GCP)

- **Committed use discounts**: 1 or 3 year commitments on Compute Engine (up to 57% savings)
- **Cloud Run scales to zero**: no idle costs. Use `--min-instances 0` unless cold starts are unacceptable
- **Preemptible/Spot VMs** for batch and fault-tolerant workloads
- **Sustained use discounts**: automatic discount for running VMs 25%+ of the month

---

## Azure

### Compute

**App Service** — managed web hosting. Supports Docker containers, Node.js, Python, .NET. Auto-scaling, deployment slots for blue-green.

```bash
# Deploy container to App Service
az webapp create \
  --name myapp \
  --resource-group mygroup \
  --plan myplan \
  --deployment-container-image-name myregistry.azurecr.io/myapp:v1

# Swap staging slot to production
az webapp deployment slot swap \
  --name myapp \
  --resource-group mygroup \
  --slot staging
```

**AKS** (Azure Kubernetes Service) — managed Kubernetes. Good Azure AD integration. Supports confidential computing.

**Azure Container Apps** — serverless containers with Dapr integration. Simpler than AKS, more flexible than App Service.

**Azure Functions** — see serverless.md for full reference.

**Container Instances** — simple single-container or container group deployments. Good for batch jobs or sidecar patterns. No orchestration overhead.

### Deployment: Azure Pipelines

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include: [main]

pool:
  vmImage: ubuntu-latest

stages:
  - stage: Test
    jobs:
      - job: Test
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: "20.x"
          - script: npm ci && npm test

  - stage: Build
    dependsOn: Test
    jobs:
      - job: BuildAndPush
        steps:
          - task: Docker@2
            inputs:
              command: buildAndPush
              repository: myapp
              containerRegistry: myAcrServiceConnection
              tags: |
                $(Build.BuildId)
                latest

  - stage: Deploy
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployToProduction
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebAppContainer@1
                  inputs:
                    azureSubscription: myServiceConnection
                    appName: myapp
                    containers: myregistry.azurecr.io/myapp:$(Build.BuildId)
```

**Azure Container Registry**:

```bash
# Login to ACR
az acr login --name myregistry

# Build and push using ACR Tasks (runs in cloud, no local Docker needed)
az acr build --registry myregistry --image myapp:v1 .
```

### IAM (Azure RBAC)

```bash
# Assign Contributor role to service principal
az role assignment create \
  --assignee <service-principal-id> \
  --role Contributor \
  --scope /subscriptions/<sub-id>/resourceGroups/mygroup

# Create managed identity for app (no credentials to manage)
az identity create --name myapp-identity --resource-group mygroup

# Assign role to managed identity
az role assignment create \
  --assignee <identity-principal-id> \
  --role "Storage Blob Data Reader" \
  --scope /subscriptions/<sub-id>/resourceGroups/mygroup/providers/Microsoft.Storage/storageAccounts/myaccount
```

Use **Managed Identities** instead of service principal credentials whenever possible. Applications running in Azure (App Service, AKS, Functions) can authenticate to Azure services without any stored credentials.

### Monitoring: Azure Monitor + Application Insights

```bash
# Stream App Service logs
az webapp log tail --name myapp --resource-group mygroup

# Query logs with Log Analytics
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AppRequests | where ResultCode >= 500 | limit 20"
```

Application Insights: instrument your app with the SDK for distributed tracing, custom metrics, and performance profiling. Integrates with Azure Monitor alerts.

### Cost Optimization (Azure)

- **Reserved instances**: 1 or 3 year commitments (up to 72% savings)
- **Azure Hybrid Benefit**: use existing Windows Server/SQL licenses in Azure
- **Spot VMs** for batch and fault-tolerant workloads (up to 90% savings)
- **Azure Dev/Test pricing**: significantly reduced rates for non-production workloads
- **App Service deployment slots**: zero-downtime swaps without running two full services
