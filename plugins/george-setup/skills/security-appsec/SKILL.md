---
name: security-appsec
description: Use when writing secure code, auditing applications, implementing authentication, authorization, cryptography, or secrets management. Use for OWASP Top 10, XSS prevention, SQL injection fixes, CSRF protection, JWT implementation, OAuth2/OIDC flows, bcrypt/argon2 password hashing, AES-256-GCM encryption, TLS configuration, HashiCorp Vault, AWS Secrets Manager, environment variable security, Semgrep SAST, Bandit, ESLint security, DAST with OWASP ZAP, npm audit, pip-audit, Snyk, Dependabot, SBOM generation, CSP headers, HSTS, CORS hardening, rate limiting, brute-force protection, API security, mTLS, GraphQL security, SOC2 compliance, GDPR data protection, PCI-DSS tokenization, HIPAA safeguards, penetration testing, security audits, secure coding checklists, input validation, output encoding, mass assignment protection, path traversal, XXE, SSRF mitigations, RBAC, ABAC, session management, key management, CVE response, incident response, data breach playbooks, container hardening, distroless images, Cosign signing, supply chain security, AppSec, application security engineering, vulnerability management.
---

# Application Security (AppSec) Skill

## Task Router

| Task | Reference File |
|------|---------------|
| OWASP Top 10 vulnerabilities, injection, auth failures, crypto | `references/owasp-top10.md` |
| JWT, OAuth2/OIDC, session management, RBAC/ABAC, API keys, MFA | `references/authentication-authorization.md` |
| AES-GCM, RSA, TLS config, HashiCorp Vault, Secrets Manager, key lifecycle | `references/cryptography-secrets.md` |
| Input validation, SQL injection, XSS, CSRF, path traversal, XXE, SSRF, file upload | `references/secure-coding-patterns.md` |
| Semgrep, Bandit, ESLint security, SonarQube, OWASP ZAP, Snyk, Trivy, SBOM | `references/sast-dast-tools.md` |
| CSP, HSTS, X-Frame-Options, CORS, cookie flags, rate limiting, nginx/Apache | `references/security-headers-hardening.md` |
| API authentication, rate limiting, GraphQL security, gRPC, error leakage | `references/api-security.md` |
| SOC2, GDPR, PCI-DSS, HIPAA, ISO 27001, compliance automation | `references/compliance-frameworks.md` |
| Credential leak, data breach, RCE, CVE response, post-mortem | `references/incident-response.md` |
| Container hardening, Cosign, SLSA, SBOM, dependency confusion, hadolint | `references/container-supply-chain.md` |

---

## Before Starting — Threat Modeling Questions

Ask these before implementing any security-relevant feature:

1. **Assets**: What data or functionality needs protecting? (PII, credentials, financial data, admin functions)
2. **Attackers**: Who might attack this? (external internet users, authenticated users, insiders, automated bots)
3. **Entry points**: Where does untrusted data enter? (HTTP request body, query params, file uploads, webhooks, env vars)
4. **Trust boundaries**: Where does data cross from one trust level to another? (public → authenticated, user → admin)
5. **Failure mode**: If this control fails, does it fail open (allow) or closed (deny)? Always prefer fail closed.
6. **Sensitive data flow**: Does this feature touch PII, credentials, or payment data? If yes, is it encrypted at rest and in transit?
7. **Authentication requirement**: Does every code path that modifies data require authentication?
8. **Rate limiting**: Can this operation be abused at volume? (password reset, login, search, export)

---

## Quick Reference — Security Checklist for New Features

### Before Writing Code
- [ ] Threat model the feature (see questions above)
- [ ] Identify all inputs that cross trust boundaries
- [ ] Determine data classification (public, internal, confidential, restricted)

### Authentication & Authorization
- [ ] Every endpoint has explicit authentication check
- [ ] Authorization checks verify ownership, not just authentication
- [ ] Admin/sensitive actions require re-authentication
- [ ] Rate limiting on all auth endpoints

### Data Handling
- [ ] Inputs validated against strict allowlist schema
- [ ] Parameterized queries for all database access
- [ ] Output encoded for context (HTML, JSON, SQL)
- [ ] PII encrypted at rest (field-level or disk encryption)
- [ ] No secrets in source code, logs, or URLs

### API Design
- [ ] No sensitive data in URL path or query string
- [ ] Error responses contain no internal details
- [ ] Request size limits configured
- [ ] CORS configured with explicit origin allowlist

### Dependencies
- [ ] New dependencies scanned for CVEs before adding
- [ ] Version pinned in lockfile
- [ ] License compatible with project

---

## Decision Trees

### Which Auth Scheme?

```
Is this user-facing (browser)?
├─ Yes → OAuth2 Authorization Code + PKCE + ID token (OIDC)
│         Sessions stored server-side; cookies: Secure+HttpOnly+SameSite=Lax
└─ No (machine-to-machine)?
   ├─ Internal service (trusted network)?
   │  ├─ High security → mTLS (mutual certificate auth)
   │  └─ Standard → OAuth2 Client Credentials or JWT (RS256)
   └─ External partner/customer API?
      ├─ Simple → API key (hashed at rest, scoped, expiring)
      └─ Delegated (user's data) → OAuth2 Authorization Code + PKCE
```

### Which Hashing Algorithm?

```
What are you hashing?
├─ Password (user authentication)
│  └─ → argon2id (preferred) or bcrypt rounds=12
│       NEVER: MD5, SHA1, SHA256, SHA512 alone
├─ API key (stored in DB for lookup)
│  └─ → SHA-256 (fast lookup acceptable; no need for slow hash)
├─ File integrity check
│  └─ → SHA-256 or SHA-3
├─ HMAC (message authentication)
│  └─ → HMAC-SHA256
└─ Password in legacy system
   └─ → bcrypt rounds=12 (upgrade to argon2id at next opportunity)
```

### Which Encryption?

```
What are you encrypting?
├─ Data at rest (database field, file)
│  ├─ Small data (<4KB) → AES-256-GCM with random nonce
│  ├─ Large file → AES-256-GCM in streaming mode
│  └─ Many records → Envelope encryption (KMS + per-record DEK)
├─ Data in transit
│  └─ → TLS 1.3 (let your framework/library handle this)
├─ Sending to specific recipient (asymmetric)
│  └─ → RSA-OAEP (encryption) or ECDSA/Ed25519 (signing)
└─ JWT tokens
   ├─ Single service (same issuer+verifier) → HS256 acceptable
   └─ Multi-service → RS256 or ES256
```

### Which Compliance Standard Applies?

```
Does your system handle...
├─ Credit/debit card data? → PCI-DSS (mandatory)
├─ Healthcare data (US)? → HIPAA (mandatory)
├─ EU personal data? → GDPR (mandatory)
├─ US federal systems? → FedRAMP/FISMA
├─ SaaS with enterprise customers? → SOC 2 Type II (expected)
└─ ISO 27001 → Internationally recognized ISMS framework
Multiple can apply simultaneously.
```

---

## Core Security Principles

### 1. Defense in Depth
Never rely on a single security control. Layer multiple independent controls so that if one fails, others catch the attack. Example: parameterized queries (injection prevention) + WAF (network layer) + input validation (application layer) for SQL injection protection.

### 2. Least Privilege
Every component (user, service account, process) should have only the minimum permissions required. IAM roles with specific resource ARNs, not `*`. Database users with only `SELECT`/`INSERT` on the tables they need.

### 3. Fail Securely
When security checks fail (exception, timeout, service unavailable), deny access — do not grant it. `return False` not `return True` in exception handlers. A broken lock is still a locked door.

### 4. Security by Default
Secure configuration should be the default — developers must opt OUT of security, not opt IN. Example: HTTPS enabled by default, cookies secure by default, rate limiting on by default.

### 5. Separation of Concerns
Separate authentication (who are you?) from authorization (what can you do?). Separate application code from secret handling. Separate build artifacts from runtime config.

### 6. Complete Mediation
Every access to every object must be checked for authorization on every access — not just on initial login. Cached authorization decisions must have short TTLs.

### 7. Minimize Attack Surface
Disable unused features, close unused ports, remove unused dependencies, delete dead code. Every line of code is a potential vulnerability.

### 8. Assume Breach
Design systems assuming attackers will get in. Use audit logging, anomaly detection, and segmentation to detect and limit damage. "Assume breach" drives better monitoring, alerting, and response readiness.

---

## CVSS Severity Quick Reference

| Score | Severity | Patch SLA | Examples |
|-------|----------|-----------|---------|
| 9.0-10.0 | Critical | 24h (4h if exploited) | RCE, SQLi with full DB access, auth bypass |
| 7.0-8.9 | High | 7 days | Stored XSS, privilege escalation, SSRF to internal |
| 4.0-6.9 | Medium | 30 days | Reflected XSS, CSRF, info disclosure |
| 0.1-3.9 | Low | 90 days | Open redirect, verbose errors |

---

## Security Code Review Checklist

Use this when reviewing PRs touching security-sensitive code:

**Authentication/Authorization**
- [ ] No hardcoded credentials or secrets
- [ ] Authentication required on all new endpoints
- [ ] Authorization checks ownership (not just authentication)
- [ ] New roles/permissions documented and reviewed

**Input/Output**
- [ ] All inputs validated (type, length, format)
- [ ] No string interpolation in SQL queries
- [ ] Output HTML-encoded before rendering
- [ ] File uploads: type validated from content, not extension

**Cryptography**
- [ ] No MD5/SHA1 for security purposes
- [ ] Secrets retrieved from Vault/KMS, not env vars
- [ ] Random values use `secrets` module or `crypto.randomBytes`

**Error Handling**
- [ ] No stack traces in error responses
- [ ] No internal paths/queries in error messages
- [ ] Exceptions in security checks fail closed

**Dependencies**
- [ ] No new packages with known critical CVEs
- [ ] Package version pinned
- [ ] No packages with 0 downloads or suspicious names
