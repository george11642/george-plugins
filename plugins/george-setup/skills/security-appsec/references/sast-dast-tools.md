# SAST, DAST & Dependency Scanning Tools Reference

---

## Semgrep — SAST

Semgrep is a fast, open-source static analysis tool with 1000+ community rules and support for custom patterns.

### Quick start
```bash
# Install
pip install semgrep

# Scan with OWASP ruleset
semgrep --config=p/owasp-top-ten .

# Python security
semgrep --config=p/python-security .

# JavaScript/TypeScript
semgrep --config=p/javascript .
semgrep --config=p/typescript .

# Multiple rulesets
semgrep --config=p/default --config=p/secrets .

# Output formats
semgrep --config=p/owasp-top-ten --json . > results.json
semgrep --config=p/owasp-top-ten --sarif . > results.sarif
```

### Custom rule example
```yaml
# rules/no-hardcoded-secrets.yaml
rules:
  - id: no-hardcoded-api-key
    patterns:
      - pattern: |
          $VAR = "..."
      - metavariable-regex:
          metavariable: $VAR
          regex: '(?i)(api_key|secret|password|token|private_key)'
      - metavariable-regex:
          metavariable: "..."
          regex: '.{8,}'  # non-trivial value
    message: "Potential hardcoded secret in $VAR"
    severity: ERROR
    languages: [python, javascript, typescript]

  - id: sql-injection-string-format
    pattern: |
      cursor.execute(f"... {$VAR} ...")
    message: "SQL injection via f-string interpolation"
    severity: ERROR
    languages: [python]
```

### CI integration (GitHub Actions)
```yaml
- name: Semgrep scan
  uses: returntocorp/semgrep-action@v1
  with:
    config: >-
      p/owasp-top-ten
      p/secrets
      p/python-security
  env:
    SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

---

## Bandit — Python Security Linter

```bash
# Install
pip install bandit

# Scan project
bandit -r src/ -ll  # only medium+ severity
bandit -r src/ -f json -o bandit-report.json

# Skip specific checks (with justification comment)
result = pickle.loads(data)  # nosec B301 -- data from internal trusted source

# Common findings:
# B301: pickle usage
# B303: MD5/SHA1 in hashlib
# B311: random not suitable for security
# B501/B502: TLS settings
# B601/B602: shell injection
# B703: django mark_safe
```

```yaml
# CI: fail on medium+ severity
- name: Bandit security scan
  run: |
    pip install bandit
    bandit -r src/ -ll -f json -o bandit.json || true
    bandit -r src/ -ll  # non-zero exit on findings
```

---

## ESLint Security Plugin (JavaScript/TypeScript)

```bash
npm install --save-dev eslint-plugin-security eslint-plugin-no-unsanitized
```

```json
// .eslintrc.json
{
  "plugins": ["security", "no-unsanitized"],
  "extends": ["plugin:security/recommended"],
  "rules": {
    "no-unsanitized/method": "error",
    "no-unsanitized/property": "error",
    "security/detect-object-injection": "warn",
    "security/detect-non-literal-regexp": "warn",
    "security/detect-unsafe-regex": "error",
    "security/detect-possible-timing-attacks": "error",
    "security/detect-eval-with-expression": "error"
  }
}
```

---

## SonarQube / SonarCloud

```yaml
# GitHub Actions — SonarCloud
- name: SonarCloud Scan
  uses: SonarSource/sonarcloud-github-action@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  with:
    args: >
      -Dsonar.projectKey=myorg_myproject
      -Dsonar.organization=myorg
      -Dsonar.sources=src
      -Dsonar.python.coverage.reportPaths=coverage.xml
```

```properties
# sonar-project.properties
sonar.projectKey=myorg_myproject
sonar.organization=myorg
sonar.sources=src
sonar.exclusions=**/*.test.ts,**/node_modules/**
sonar.security.hotspots.inheritanceValues=ALL
```

**Quality Gate**: Set gate to fail on new Vulnerabilities (Critical/High) or Security Hotspots unreviewed.

---

## OWASP ZAP — DAST

### Baseline scan in CI (passive scan, no attacks)
```yaml
- name: ZAP Baseline Scan
  uses: zaproxy/action-baseline@v0.12.0
  with:
    target: "https://staging.myapp.com"
    rules_file_name: ".zap/rules.tsv"
    cmd_options: "-I"  # ignore warnings as failures
    fail_action: true   # fail on alerts

- name: Upload ZAP report
  uses: actions/upload-artifact@v3
  with:
    name: zap-report
    path: report_html.html
```

### Full scan (active scan — use only on dedicated test environment)
```yaml
- name: ZAP Full Scan
  uses: zaproxy/action-full-scan@v0.10.0
  with:
    target: "https://test.myapp.com"
    rules_file_name: ".zap/rules.tsv"
```

```tsv
# .zap/rules.tsv — suppress known false positives
10020	IGNORE	(X-Frame-Options Header)  # handled by CSP frame-ancestors
10021	IGNORE	(X-Content-Type-Options Header)  # set elsewhere
```

### ZAP API scan (for OpenAPI/GraphQL)
```yaml
- name: ZAP API Scan
  uses: zaproxy/action-api-scan@v0.7.0
  with:
    target: "https://api.myapp.com"
    format: openapi
    file: openapi.yaml
```

---

## Dependency Scanning

### npm audit
```bash
# Fail on high/critical vulnerabilities
npm audit --audit-level=high

# JSON output for CI processing
npm audit --json | jq '.vulnerabilities | to_entries[] | select(.value.severity == "critical") | .key'

# Auto-fix non-breaking
npm audit fix
```

### pip-audit (Python)
```bash
pip install pip-audit
pip-audit                         # scan current env
pip-audit -r requirements.txt    # scan from file
pip-audit --format=json          # JSON output
pip-audit --fix                  # auto-fix where possible
```

### Trivy — containers, repos, SBOMs
```bash
# Scan container image
trivy image --severity HIGH,CRITICAL myapp:latest

# Scan filesystem/repo
trivy fs --severity CRITICAL .

# Scan IaC
trivy config terraform/

# Generate SBOM
trivy image --format spdx-json --output sbom.json myapp:latest

# CI: fail on critical CVEs
trivy image --exit-code 1 --severity CRITICAL myapp:latest
```

### Snyk — comprehensive SCA + SAST
```bash
# Install
npm install -g snyk
snyk auth

# Test dependencies
snyk test
snyk test --severity-threshold=high

# Test Docker image
snyk container test myapp:latest

# Monitor (continuous)
snyk monitor

# Fix
snyk wizard  # interactive
```

```yaml
# Snyk GitHub Actions
- name: Snyk Security Scan
  uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    args: --severity-threshold=high --fail-on=all
```

---

## Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    groups:
      dev-dependencies:
        patterns: ["eslint*", "@types/*", "jest*"]
    ignore:
      - dependency-name: "lodash"
        versions: ["< 4.0.0"]  # skip downgrade

  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

---

## SBOM Generation

```bash
# syft — generates SBOM from images, directories, archives
brew install anchore/syft/syft

# Generate SBOM in SPDX format
syft myapp:latest -o spdx-json > sbom.spdx.json
syft . -o cyclonedx-json > sbom.cdx.json

# Attest SBOM to image (requires Cosign)
syft attest --output spdx-json myapp:latest | \
  cosign attest --predicate - --type spdxjson myapp:latest

# Verify SBOM attestation
cosign verify-attestation --type spdxjson --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer "https://accounts.google.com" myapp:latest
```

---

## CI Security Pipeline — Complete Example

```yaml
# .github/workflows/security.yml
name: Security Scans
on: [push, pull_request]

jobs:
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: p/owasp-top-ten p/secrets
      - name: Bandit (Python)
        run: pip install bandit && bandit -r src/ -ll

  dependency-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: npm audit
        run: npm audit --audit-level=high
      - name: Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          severity: CRITICAL,HIGH
          exit-code: 1

  dast:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: ZAP Baseline
        uses: zaproxy/action-baseline@v0.12.0
        with:
          target: "https://staging.myapp.com"
```

---

## Tool Selection Guide

| Need | Tool |
|------|------|
| Fast SAST, custom rules | Semgrep |
| Python-specific security | Bandit |
| JS/TS security linting | ESLint security plugins |
| Enterprise SAST + quality | SonarQube/SonarCloud |
| DAST (passive) in CI | OWASP ZAP baseline |
| DAST (active) | OWASP ZAP full / Burp Suite |
| Node.js dependencies | npm audit + Snyk |
| Python dependencies | pip-audit + Safety |
| Container image CVEs | Trivy or Grype |
| Multi-language SCA | Snyk |
| Auto PRs for updates | Dependabot |
| SBOM generation | syft |
| Secret scanning | detect-secrets, gitleaks, truffleHog |
