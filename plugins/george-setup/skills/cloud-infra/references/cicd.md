# CI/CD Reference

## GitHub Actions

### Triggers

```yaml
on:
  # Push to specific branches
  push:
    branches: [main, develop, "release/**"]
    tags: ["v*"]
    paths-ignore: ["**.md", "docs/**"]

  # Pull request events
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]

  # Scheduled (cron syntax, UTC)
  schedule:
    - cron: "0 6 * * 1-5"  # Weekdays at 6am UTC

  # Manual with inputs
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        default: "staging"
        type: choice
        options: [staging, production]
      skip_tests:
        description: "Skip test suite"
        type: boolean
        default: false

  # Triggered by another workflow via API
  repository_dispatch:
    types: [deploy-trigger, rollback-trigger]
```

Why `paths-ignore`: avoid running expensive CI on documentation-only changes. Saves both time and CI minutes.

### Job Structure and Dependencies

```yaml
jobs:
  # Job 1: runs independently
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test

  # Job 2: runs independently
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint

  # Job 3: depends on both test AND lint passing
  build:
    needs: [test, lint]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run build

  # Job 4: deploy only after build, only on main branch
  deploy:
    needs: [build]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - run: echo "deploying..."
```

### Conditional Execution

```yaml
steps:
  # Run only on PRs
  - name: PR-only check
    if: github.event_name == 'pull_request'
    run: echo "PR check"

  # Run only on main branch pushes
  - name: Deploy to production
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    run: ./scripts/deploy.sh

  # Run only on tagged releases
  - name: Create GitHub release
    if: startsWith(github.ref, 'refs/tags/v')
    run: gh release create ${{ github.ref_name }}

  # Run only when previous step succeeded (default)
  - name: Normal step
    run: echo "runs unless cancelled or failed"

  # Always run (e.g., cleanup, notifications)
  - name: Always notify
    if: always()
    run: ./notify.sh "${{ job.status }}"

  # Run only on failure
  - name: Debug on failure
    if: failure()
    run: ./collect-debug-info.sh

  # Combine conditions
  - name: Production alert
    if: failure() && github.ref == 'refs/heads/main'
    run: ./alert-oncall.sh
```

### Matrix Strategies

```yaml
jobs:
  test:
    strategy:
      # Don't cancel all matrix jobs if one fails
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node-version: ["18", "20", "22"]
        # Exclude specific combinations
        exclude:
          - os: windows-latest
            node-version: "18"
        # Add extra values to specific combinations
        include:
          - os: ubuntu-latest
            node-version: "20"
            experimental: true

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm test
```

### Artifacts: Upload and Download Between Jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run build
      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          retention-days: 7
          # Fail if no files match
          if-no-files-found: error

  deploy:
    needs: [build]
    runs-on: ubuntu-latest
    steps:
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: build-output
          path: dist/
      - run: ./deploy.sh dist/

  # Download multiple artifacts
  publish:
    needs: [build-linux, build-macos, build-windows]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          # Omitting 'name' downloads all artifacts
          path: artifacts/
      # artifacts/build-linux/, artifacts/build-macos/, etc.
```

### Caching

```yaml
steps:
  # Node.js dependencies cache
  - uses: actions/cache@v4
    id: npm-cache
    with:
      path: ~/.npm
      # Cache key based on OS + lockfile hash
      key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
      # Fallback keys (partial match on prefix)
      restore-keys: |
        ${{ runner.os }}-npm-

  - run: npm ci

  # Python dependencies cache
  - uses: actions/cache@v4
    with:
      path: ~/.cache/pip
      key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
      restore-keys: ${{ runner.os }}-pip-

  # Docker layer cache (BuildKit)
  - uses: actions/cache@v4
    with:
      path: /tmp/.buildx-cache
      key: ${{ runner.os }}-buildx-${{ github.sha }}
      restore-keys: ${{ runner.os }}-buildx-

  - name: Build Docker image
    uses: docker/build-push-action@v5
    with:
      cache-from: type=local,src=/tmp/.buildx-cache
      cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max

  # Move cache (prevent unbounded growth)
  - run: |
      rm -rf /tmp/.buildx-cache
      mv /tmp/.buildx-cache-new /tmp/.buildx-cache
```

Why `hashFiles`: ensures the cache key changes whenever dependencies change. The lockfile hash guarantees reproducibility -- same lockfile always restores the same cache.

### Secrets and Environment Variables

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    # Environment-level secrets and approval gates
    environment: production
    env:
      # Job-level env vars (non-sensitive)
      NODE_ENV: production
      APP_VERSION: ${{ github.ref_name }}

    steps:
      - name: Deploy
        env:
          # Step-level access to secrets (preferred: limits scope)
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: ./deploy.sh

      # Using OIDC instead of long-lived credentials (preferred for AWS)
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1

      # Mask dynamic secrets in logs
      - name: Get DB password
        run: |
          PASSWORD=$(aws secretsmanager get-secret-value --secret-id prod/db --query SecretString --output text)
          echo "::add-mask::$PASSWORD"
          echo "DB_PASS=$PASSWORD" >> $GITHUB_ENV
```

### Environments with Approval Gates

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - run: ./deploy.sh staging

  deploy-production:
    needs: [deploy-staging]
    runs-on: ubuntu-latest
    # 'production' environment configured in repo settings with required reviewers
    environment:
      name: production
      url: https://app.example.com
    steps:
      - run: ./deploy.sh production
```

Configure environments in GitHub repo Settings > Environments. Set required reviewers, wait timers (up to 30 days), and restrict to specific branches.

### Complete CI/CD Pipeline Example

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm test
        env:
          DATABASE_URL: postgres://postgres:testpass@localhost:5432/testdb

  build-and-push:
    needs: [test]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - uses: aws-actions/amazon-ecr-login@v2
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.ECR_REGISTRY }}/myapp
          tags: |
            type=sha,prefix=,suffix=,format=short
            type=raw,value=latest
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  deploy:
    needs: [build-and-push]
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster production \
            --service myapp \
            --force-new-deployment
```

---

## GitLab CI

### Pipeline Syntax and Stages

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

# Job template (anchors)
.base-job: &base-job
  image: node:20-alpine
  before_script:
    - npm ci --cache .npm --prefer-offline
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .npm/

test:
  <<: *base-job
  stage: test
  script:
    - npm test
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    when: always
    expire_in: 1 week

build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG
  only:
    - main
    - tags
```

### Rules vs only/except

```yaml
# Modern approach: rules (preferred over only/except)
deploy-staging:
  stage: deploy
  script: ./deploy.sh staging
  rules:
    # Run on main branch push (not MR)
    - if: $CI_COMMIT_BRANCH == "main" && $CI_PIPELINE_SOURCE != "merge_request_event"
    # Run manually on other branches
    - if: $CI_PIPELINE_SOURCE == "push"
      when: manual

deploy-production:
  stage: deploy
  script: ./deploy.sh production
  rules:
    # Only on version tags
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  environment:
    name: production
    url: https://app.example.com
```

### Artifacts and Dependencies

```yaml
build:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

deploy:
  stage: deploy
  # Explicitly download only this job's artifacts
  dependencies:
    - build
  script:
    - ls dist/  # Available from 'build' job
```

### GitLab CI Caching

```yaml
test:
  cache:
    # Shared cache across all branches
    key: $CI_PROJECT_PATH
    paths:
      - .npm/
    policy: pull-push  # Pull on start, push on end (default)

build:
  cache:
    key: $CI_COMMIT_REF_SLUG  # Per-branch cache
    paths:
      - node_modules/
    policy: pull  # Only pull, don't update (read-only)
```

### Protected Environments

```yaml
deploy-production:
  stage: deploy
  environment:
    name: production
  script: ./deploy.sh
  when: manual  # Requires manual trigger
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
      allow_failure: false
```

Configure protected environments in GitLab project Settings > CI/CD > Environments. Restrict deployments to specific users/groups with approval requirements.

---

## Common Patterns

### Multi-Platform Builds with Parallel Jobs

```yaml
# GitHub Actions: parallel multi-arch Docker builds
jobs:
  build-amd64:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          platforms: linux/amd64
          push: true
          tags: myapp:amd64

  build-arm64:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/build-push-action@v5
        with:
          platforms: linux/arm64
          push: true
          tags: myapp:arm64

  merge-manifest:
    needs: [build-amd64, build-arm64]
    runs-on: ubuntu-latest
    steps:
      - run: |
          docker manifest create myapp:latest myapp:amd64 myapp:arm64
          docker manifest push myapp:latest
```

### PR Preview Deployments

```yaml
# Deploy ephemeral preview environment on PR open/update
jobs:
  preview:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy preview
        id: deploy
        run: |
          PREVIEW_URL=$(./deploy-preview.sh pr-${{ github.event.pull_request.number }})
          echo "url=$PREVIEW_URL" >> $GITHUB_OUTPUT
      - name: Comment preview URL on PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Preview deployed: ${{ steps.deploy.outputs.url }}'
            })

  cleanup-preview:
    if: github.event.action == 'closed'
    runs-on: ubuntu-latest
    steps:
      - run: ./teardown-preview.sh pr-${{ github.event.pull_request.number }}
```

### Tag-Based Production Releases

```yaml
on:
  push:
    tags: ["v*"]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for changelog
      - name: Build release artifacts
        run: make build
      - name: Create GitHub release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            dist/*.tar.gz
            dist/*.zip
          generate_release_notes: true
      - name: Deploy to production
        run: ./deploy.sh production ${{ github.ref_name }}
```

### Rollback Strategies

```yaml
# Option 1: Revert via git (triggers CI)
# git revert <bad-commit> && git push

# Option 2: Manual rollback workflow
name: Rollback
on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Docker image tag to roll back to (e.g. abc1234)"
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - name: Update ECS task definition to previous image
        run: |
          TASK_DEF=$(aws ecs describe-task-definition --task-definition myapp --query taskDefinition)
          NEW_TASK_DEF=$(echo $TASK_DEF | jq --arg TAG "${{ inputs.image_tag }}" \
            '.containerDefinitions[0].image |= (split(":")[0] + ":" + $TAG)')
          NEW_ARN=$(aws ecs register-task-definition --cli-input-json "$NEW_TASK_DEF" --query taskDefinition.taskDefinitionArn --output text)
          aws ecs update-service --cluster production --service myapp --task-definition $NEW_ARN
```

### Status Checks and Required Reviews

Configure branch protection rules in GitHub Settings > Branches:
- **Required status checks**: Block merge until specific jobs pass (e.g., `test`, `lint`)
- **Require approvals**: Minimum 1-2 reviewers before merge
- **Dismiss stale reviews**: Re-request review on new commits
- **Require signed commits**: Verify commit author identity
- **Restrict pushes**: Only allow merges via PR

```yaml
# Jobs that should be required status checks
jobs:
  # Name this exactly as it appears in branch protection settings
  test:
    name: "Test Suite"
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  security-scan:
    name: "Security Scan"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

---

## Anti-Patterns

1. **Storing secrets in workflow files** -- use GitHub Secrets or OIDC, never hardcode credentials in YAML
2. **Using `latest` tags for actions** -- pin to a specific SHA or version (`actions/checkout@v4`, not `actions/checkout@latest`). Security: a compromised action at `latest` can exfiltrate secrets
3. **Not caching dependencies** -- re-downloading npm/pip/maven packages on every run wastes 2-5 minutes per build
4. **Monolithic single-job pipelines** -- no parallelism, no caching benefit between stages, harder to debug
5. **Auto-applying Terraform to production** -- always require human approval for prod. Use environments with required reviewers
6. **Not setting job timeouts** -- a hanging test can consume runner minutes for hours. Set `timeout-minutes: 30` on every job
7. **Ignoring artifact expiry** -- artifacts accumulate. Set `retention-days` to keep storage costs down
