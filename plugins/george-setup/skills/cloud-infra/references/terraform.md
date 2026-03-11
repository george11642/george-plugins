# Terraform Reference

## Module Structure

### Standard Layout

```
infrastructure/
  modules/
    networking/
      main.tf
      variables.tf
      outputs.tf
      README.md
    compute/
      main.tf
      variables.tf
      outputs.tf
    database/
      main.tf
      variables.tf
      outputs.tf
  environments/
    dev/
      main.tf         # Calls modules with dev values
      backend.tf      # Remote state config
      terraform.tfvars
    staging/
      main.tf
      backend.tf
      terraform.tfvars
    prod/
      main.tf
      backend.tf
      terraform.tfvars
```

Why this structure: modules are reusable. Environments compose modules with different inputs. Each environment has its own state file, so a mistake in dev can't corrupt prod state.

### Module Anatomy

```hcl
# modules/networking/variables.tf
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

# modules/networking/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.environment}-private-${var.availability_zones[count.index]}"
    Type = "private"
  }
}

# modules/networking/outputs.tf
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the created VPC"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of private subnet IDs"
}
```

### Environment Composition

```hcl
# environments/prod/main.tf
module "networking" {
  source             = "../../modules/networking"
  vpc_cidr           = "10.0.0.0/16"
  environment        = "prod"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "compute" {
  source            = "../../modules/compute"
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_subnet_ids
  instance_type     = "t3.large"
  min_size          = 3
  max_size          = 10
  environment       = "prod"
}
```

## State Management

### Remote Backend (AWS)

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

Why DynamoDB locking: prevents two people running `terraform apply` simultaneously, which would corrupt state. Always enable locking for shared state.

### State Operations

```bash
# List all resources in state
terraform state list

# Show details of a specific resource
terraform state show aws_instance.web

# Move a resource (after refactoring)
terraform state mv aws_instance.web module.compute.aws_instance.web

# Remove from state without destroying (when importing to another state)
terraform state rm aws_instance.web

# Import an existing resource into state
terraform import aws_instance.web i-1234567890abcdef0
```

## Workspaces

Use workspaces for same-config, different-environment deployments (simple cases). For complex environments with different resources, use separate directories.

```bash
terraform workspace new staging
terraform workspace select staging
terraform workspace list

# Reference in config
resource "aws_instance" "web" {
  instance_type = terraform.workspace == "prod" ? "t3.large" : "t3.micro"
}
```

Why directories over workspaces for complex envs: workspaces share the same config. If prod needs different resources than dev (e.g., a WAF, multi-AZ database), separate directories are clearer.

## Best Practices

### Variables and Locals

```hcl
# Use locals for computed values and DRY tags
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    CostCenter  = var.cost_center
  }
}

resource "aws_instance" "web" {
  # ...
  tags = merge(local.common_tags, {
    Name = "${var.environment}-web"
    Role = "web-server"
  })
}
```

### Data Sources

Use data sources to reference existing infrastructure without managing it:

```hcl
# Look up existing resources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
```

### Lifecycle Rules

```hcl
resource "aws_instance" "web" {
  # ...

  lifecycle {
    create_before_destroy = true  # Zero-downtime replacement
    prevent_destroy       = true  # Safety net for critical resources
    ignore_changes        = [tags["UpdatedAt"]]  # Ignore external changes
  }
}
```

### Sensitive Values

```hcl
variable "db_password" {
  type      = string
  sensitive = true  # Prevents display in plan output
}

# Better: read from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/database/password"
}
```

## for_each vs count

```hcl
# PREFER for_each -- resources are keyed by name, not index
# Removing an item from the middle doesn't shift all subsequent resources
resource "aws_iam_user" "users" {
  for_each = toset(["alice", "bob", "charlie"])
  name     = each.key
}

# count is fine for simple numeric scaling
resource "aws_subnet" "private" {
  count      = 3
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
}
```

Why for_each over count: with count, removing item [1] from a list of 3 causes items [2] to become [1], triggering a destroy+recreate. for_each uses map keys, so removing "bob" only affects that one resource.

## Terraform CI/CD

```yaml
# GitHub Actions workflow
- name: Terraform Plan
  run: |
    terraform init -backend-config=backend.hcl
    terraform plan -out=plan.tfplan -no-color
    terraform show -json plan.tfplan > plan.json

- name: Post Plan to PR
  uses: actions/github-script@v7
  with:
    script: |
      // Post plan output as PR comment for review
```

Always run `plan` in CI and require human approval before `apply` in production. Automated apply is acceptable for dev/staging.

## Common Gotchas

1. **Forgetting to run `terraform init` after adding providers/modules** -- init downloads providers and initializes the backend
2. **Circular dependencies** -- Terraform detects direct cycles but not indirect ones through data sources. Use `depends_on` explicitly when needed
3. **Provider version drift** -- pin provider versions in `required_providers` block. Unpinned providers auto-upgrade and can break
4. **State file contains secrets** -- Terraform state stores all attribute values in plaintext, including passwords. Encrypt state at rest, restrict access
5. **`terraform destroy` is permanent** -- there is no undo. Use `prevent_destroy` lifecycle on critical resources
6. **Large blast radius** -- split infrastructure into smaller state files. A single state file for all infra means any change risks everything
7. **Not using `-target` carefully** -- `terraform apply -target=resource` skips dependency calculation. Use only for debugging, never in automation
