---
name: security-deep
description: "Use for security audits, vulnerability analysis, threat modeling, compliance, and incident response. Triggers on OWASP, XSS, SQL injection, CSRF, security audit, penetration testing, pen test, CVE, vulnerability, threat model, security review, SOC2, GDPR, PCI-DSS, HIPAA, compliance audit, CSP headers, HSTS, CORS policy, RBAC, ABAC, key rotation, encryption, AES-256, TLS, mTLS, bcrypt, argon2, Semgrep, OWASP ZAP, Snyk, Trivy, SBOM, container hardening, supply chain security, Cosign, SLSA, incident response, security posture, HashiCorp Vault, key management."
---

# Application Security (Deep)

Deep security skill for architecture-level security decisions: auth design, cryptography, compliance, tooling, and incident response. Basic security checks (parameterized queries, no hardcoded secrets, input validation) belong in convention-check hooks -- this skill covers the WHY and HOW of security engineering.

## Task Router

| Task | Reference |
|------|-----------|
| OWASP Top 10, injection, broken auth, crypto failures | [references/owasp-top10.md](references/owasp-top10.md) |
| JWT, OAuth2/OIDC, session mgmt, RBAC/ABAC, MFA | [references/authentication-authorization.md](references/authentication-authorization.md) |
| AES-GCM, RSA, TLS config, Vault, key lifecycle | [references/cryptography-secrets.md](references/cryptography-secrets.md) |
| Input validation, SQLi, XSS, CSRF, SSRF, file upload | [references/secure-coding-patterns.md](references/secure-coding-patterns.md) |
| Semgrep, Bandit, ESLint security, ZAP, Snyk, Trivy | [references/sast-dast-tools.md](references/sast-dast-tools.md) |
| CSP, HSTS, CORS, cookie flags, rate limiting | [references/security-headers-hardening.md](references/security-headers-hardening.md) |
| API auth, rate limiting, GraphQL, gRPC, error leakage | [references/api-security.md](references/api-security.md) |
| SOC2, GDPR, PCI-DSS, HIPAA, ISO 27001 | [references/compliance-frameworks.md](references/compliance-frameworks.md) |
| Credential leak, data breach, RCE, CVE, post-mortem | [references/incident-response.md](references/incident-response.md) |
| Container hardening, Cosign, SLSA, SBOM, supply chain | [references/container-supply-chain.md](references/container-supply-chain.md) |

## When to Use This Skill

- Designing auth/authz architecture for a new system
- Choosing encryption algorithms or key management strategy
- Setting up SAST/DAST pipeline in CI/CD
- Preparing for SOC2/GDPR/PCI-DSS compliance audit
- Responding to a security incident or CVE
- Hardening container images and supply chain
- Reviewing API security posture
- Threat modeling a new feature

## Core Principles

1. **Defense in depth** -- layer multiple independent controls; never rely on one
2. **Least privilege** -- minimum permissions for every component
3. **Fail securely** -- deny access on error, not grant it
4. **Assume breach** -- design for detection and containment, not just prevention
5. **Security by default** -- secure config is the default; developers opt OUT, not IN
6. **Complete mediation** -- check authorization on every access, not just login

## CVSS Severity Quick Reference

| Score | Severity | Patch SLA | Examples |
|-------|----------|-----------|---------|
| 9.0-10.0 | Critical | 24h (4h if exploited) | RCE, SQLi with full DB access, auth bypass |
| 7.0-8.9 | High | 7 days | Stored XSS, privilege escalation, SSRF |
| 4.0-6.9 | Medium | 30 days | Reflected XSS, CSRF, info disclosure |
| 0.1-3.9 | Low | 90 days | Open redirect, verbose errors |

## Layer 3 Skills

- **auth-clerk** — Clerk authentication and authorization setup
- **monitoring-sentry** — Security incident monitoring via Sentry
