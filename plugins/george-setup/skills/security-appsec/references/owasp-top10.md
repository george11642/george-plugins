# OWASP Top 10 — 2021/2025 Reference

> 2025 update: A02 Security Misconfiguration moved to #2; SSRF merged into A01; "Vulnerable Components" broadened to "Software Supply Chain Failures"; A10 is now "Mishandling of Exceptional Conditions".

---

## A01 — Broken Access Control (+ SSRF in 2025)

**What it is**: Users acting outside their intended permissions. Includes IDOR, privilege escalation, path traversal, missing auth on API endpoints, SSRF.

**Vulnerable — IDOR**
```python
# No ownership check
@app.get("/invoice/{invoice_id}")
def get_invoice(invoice_id: int, user=Depends(get_current_user)):
    return db.query(Invoice).filter(Invoice.id == invoice_id).first()
```

**Secure — IDOR fixed**
```python
@app.get("/invoice/{invoice_id}")
def get_invoice(invoice_id: int, user=Depends(get_current_user)):
    invoice = db.query(Invoice).filter(
        Invoice.id == invoice_id,
        Invoice.owner_id == user.id  # ownership check
    ).first()
    if not invoice:
        raise HTTPException(status_code=404)
    return invoice
```

**Vulnerable — SSRF**
```python
# Attacker passes url=http://169.254.169.254/latest/meta-data/
def fetch_url(url: str):
    return requests.get(url).text
```

**Secure — SSRF mitigated**
```python
from urllib.parse import urlparse
ALLOWED_SCHEMES = {"https"}
BLOCKED_HOSTS = {"169.254.169.254", "::1", "localhost", "0.0.0.0"}

def fetch_url(url: str):
    parsed = urlparse(url)
    if parsed.scheme not in ALLOWED_SCHEMES:
        raise ValueError("Scheme not allowed")
    if parsed.hostname in BLOCKED_HOSTS:
        raise ValueError("Host not allowed")
    # Also resolve DNS and check resolved IP against block list
    return requests.get(url, timeout=5).text
```

**Detection patterns**: Missing `WHERE owner_id = ?`, direct object references in URLs, no authorization middleware, fetch/curl of user-supplied URLs.

**Fix patterns**: Deny by default; check ownership on every data access; use allowlist for SSRF targets; implement ABAC/RBAC centrally.

---

## A02 — Security Misconfiguration (was A05 in 2021, now #2 in 2025)

**What it is**: Default credentials, open cloud storage, verbose error messages, unnecessary features enabled, missing security headers.

**Vulnerable**
```yaml
# docker-compose.yml
services:
  db:
    image: postgres
    environment:
      POSTGRES_PASSWORD: postgres  # default
    ports:
      - "5432:5432"  # exposed to internet
```

**Secure**
```yaml
services:
  db:
    image: postgres
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    # No ports exposed; only internal network
    networks:
      - internal
```

**Vulnerable — verbose errors**
```python
@app.exception_handler(Exception)
async def global_exception(request, exc):
    return JSONResponse({"error": str(exc), "traceback": traceback.format_exc()})
```

**Secure**
```python
@app.exception_handler(Exception)
async def global_exception(request, exc):
    log.error("Unhandled exception", exc_info=exc, request_id=request.state.id)
    return JSONResponse({"error": "Internal server error", "id": request.state.id}, status_code=500)
```

**Detection**: Default creds in configs, debug=True in production, open S3 buckets, missing security headers, unnecessary HTTP methods enabled.

**Fix patterns**: Infrastructure-as-code security scanning (checkov, tfsec); CIS benchmarks; automated config drift detection.

---

## A03 — Injection (SQL, NoSQL, OS, LDAP, Template)

**Vulnerable — SQL injection**
```python
# Never do this
query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
cursor.execute(query)
```

**Secure — parameterized query**
```python
cursor.execute(
    "SELECT * FROM users WHERE username = %s AND password = %s",
    (username, hashed_password)
)
```

**Vulnerable — NoSQL injection (MongoDB)**
```javascript
// Attacker sends: {"username": {"$gt": ""}, "password": {"$gt": ""}}
User.findOne({ username: req.body.username, password: req.body.password })
```

**Secure**
```javascript
const username = String(req.body.username);  // force string
const password = String(req.body.password);
// Use hashed comparison, never store plain passwords
```

**Vulnerable — OS command injection**
```python
import subprocess
subprocess.run(f"ping {host}", shell=True)  # shell=True is dangerous
```

**Secure**
```python
import subprocess, shlex
# Validate host is an IP or known hostname first
subprocess.run(["ping", "-c", "1", host], shell=False, timeout=5)
```

**Vulnerable — SSTI (Jinja2)**
```python
template = Template(f"Hello {user_input}")  # user controls template
```

**Secure**
```python
template = Template("Hello {{ name }}")
template.render(name=user_input)  # data, not template structure
```

**Detection**: String concatenation in queries, `shell=True`, `eval()`, `exec()`, `render_template_string()` with user input.

---

## A04 — Insecure Design

**What it is**: Missing threat modeling, no rate limiting, business logic flaws, insecure-by-default architecture.

**Example — missing rate limiting**
```python
# Vulnerable: unlimited password reset attempts
@app.post("/reset-password")
def reset_password(email: str):
    send_reset_email(email)

# Secure: rate limit + account enumeration prevention
@app.post("/reset-password")
@limiter.limit("3/hour")
def reset_password(email: str):
    # Always return same response whether email exists or not
    user = db.get_user_by_email(email)
    if user:
        send_reset_email(user)
    return {"message": "If that email exists, a reset link has been sent"}
```

**Threat modeling questions (STRIDE)**:
- Spoofing: Can users impersonate others?
- Tampering: Can users modify data they shouldn't?
- Repudiation: Can users deny their actions?
- Information Disclosure: What sensitive data is exposed?
- Denial of Service: Can the system be flooded?
- Elevation of Privilege: Can users gain higher permissions?

---

## A05 — Cryptographic Failures (was A02 in 2021)

**Vulnerable — MD5/SHA1 for passwords**
```python
import hashlib
hashed = hashlib.md5(password.encode()).hexdigest()  # NEVER
```

**Secure — bcrypt/argon2**
```python
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
hashed = pwd_context.hash(password)
verified = pwd_context.verify(password, hashed)
```

**Vulnerable — ECB mode**
```python
from Crypto.Cipher import AES
cipher = AES.new(key, AES.MODE_ECB)  # ECB leaks patterns
```

**Secure — AES-GCM with random nonce**
```python
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os
key = os.urandom(32)  # 256-bit key
nonce = os.urandom(12)  # 96-bit nonce, never reuse
aesgcm = AESGCM(key)
ciphertext = aesgcm.encrypt(nonce, plaintext, associated_data)
# Store: nonce + ciphertext
```

**Vulnerable — hardcoded secrets**
```python
SECRET_KEY = "super-secret-key-1234"  # in source code
```

**Detection**: MD5/SHA1 for passwords, ECB mode, hardcoded keys, HTTP (not HTTPS), weak TLS configs, unencrypted PII at rest.

---

## A06 — Vulnerable and Outdated Components / Supply Chain Failures (2025)

**What it is**: Known CVEs in dependencies, abandoned libraries, compromised packages (typosquatting, dependency confusion).

**Audit commands**
```bash
# Node.js
npm audit --audit-level=high
npx snyk test

# Python
pip-audit
safety check

# Container images
trivy image myapp:latest
grype myapp:latest

# SBOM generation
syft myapp:latest -o spdx-json > sbom.json
```

**CI enforcement (GitHub Actions)**
```yaml
- name: Dependency audit
  run: npm audit --audit-level=critical
  # Fail pipeline on critical CVEs

- name: Container scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    severity: CRITICAL,HIGH
    exit-code: 1
```

**Dependency confusion defense**
```bash
# .npmrc — always use private registry for @myorg scope
@myorg:registry=https://registry.mycompany.com/
```

**Detection**: Outdated lockfiles, no dependency scanning in CI, packages from unexpected registries.

---

## A07 — Identification and Authentication Failures

**Vulnerable — no account lockout**
```python
@app.post("/login")
def login(username: str, password: str):
    user = db.get(username)
    if user and check_password(password, user.password_hash):
        return create_session(user)
    return {"error": "Invalid credentials"}  # unlimited retries
```

**Secure — lockout + rate limiting**
```python
@app.post("/login")
@limiter.limit("5/minute;20/hour")
def login(username: str, password: str):
    # Constant-time comparison prevents timing attacks
    user = db.get(username)
    # Always hash even if user not found (timing attack prevention)
    dummy_hash = "$argon2id$v=19$..."
    candidate_hash = user.password_hash if user else dummy_hash
    if not pwd_context.verify(password, candidate_hash) or not user:
        increment_failed_attempts(username)
        if get_failed_attempts(username) >= 5:
            lock_account(username, duration=timedelta(minutes=15))
        raise HTTPException(status_code=401)
    reset_failed_attempts(username)
    return create_session(user)
```

**Secure JWT handling**
```python
import jwt
# Use RS256 (asymmetric) not HS256 for distributed systems
token = jwt.encode(
    {"sub": user.id, "exp": datetime.utcnow() + timedelta(hours=1), "jti": str(uuid4())},
    private_key,
    algorithm="RS256"
)
# Verify: always check exp, iss, aud
decoded = jwt.decode(token, public_key, algorithms=["RS256"],
                     options={"require": ["exp", "iss", "aud"]})
```

**Detection**: No MFA, weak passwords allowed, session IDs in URLs, no logout invalidation, JWT with `alg: none`.

---

## A08 — Software and Data Integrity Failures

**What it is**: Unsigned updates, insecure CI/CD pipelines, deserialization of untrusted data.

**Vulnerable — insecure deserialization**
```python
import pickle
data = pickle.loads(user_supplied_bytes)  # arbitrary code execution
```

**Secure**
```python
import json
data = json.loads(user_supplied_string)  # safe: no code execution
# If binary format needed, use msgpack or protobuf with schema validation
```

**CI/CD integrity**
```yaml
# Pin actions to SHA, not tags
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
# Verify artifact signatures
- run: cosign verify-blob --certificate cert.pem --signature sig.sig artifact.tar.gz
```

**Detection**: `pickle.loads()` of user data, auto-update without signature verification, unpinned CI dependencies.

---

## A09 — Security Logging and Monitoring Failures

**What it is**: Missing audit logs, no alerting on suspicious activity, logs that leak sensitive data.

**What to log**
```python
# Security events that MUST be logged
SECURITY_EVENTS = [
    "login_success", "login_failure", "logout",
    "password_change", "mfa_enabled", "mfa_disabled",
    "permission_denied", "account_locked",
    "data_export", "admin_action",
    "api_key_created", "api_key_revoked"
]

def log_security_event(event_type: str, user_id: str, ip: str, metadata: dict):
    logger.info({
        "event": event_type,
        "user_id": user_id,
        "ip": ip,
        "timestamp": datetime.utcnow().isoformat(),
        "request_id": get_request_id(),
        **metadata
        # NEVER log: passwords, tokens, PII, card numbers
    })
```

**Alert thresholds**
- 5+ failed logins from one IP in 5 minutes → alert
- Admin action outside business hours → alert
- Data export > normal volume → alert
- New admin account created → alert (PagerDuty)

**Detection**: No logging middleware, logs with plaintext passwords, no SIEM integration, no retention policy.

---

## A10 — Mishandling of Exceptional Conditions (new in 2025; was SSRF in 2021)

**What it is**: Improper error handling causing fail-open behavior, logic errors, information disclosure via error messages.

**Vulnerable — fail open**
```python
def check_permission(user_id, resource_id):
    try:
        return permission_service.check(user_id, resource_id)
    except Exception:
        return True  # FAIL OPEN — grants access on error!
```

**Secure — fail closed**
```python
def check_permission(user_id, resource_id):
    try:
        return permission_service.check(user_id, resource_id)
    except Exception as e:
        log.error("Permission check failed", exc_info=e, user=user_id, resource=resource_id)
        return False  # FAIL CLOSED — deny on error
```

**Vulnerable — exception swallowing**
```python
try:
    validate_token(token)
except Exception:
    pass  # silently ignores invalid token
```

**Detection**: `except: pass`, `return True` in exception handlers, catch-all handlers with no logging, missing null checks before resource access.

---

## Quick OWASP Remediation Matrix

| Vuln | Primary Fix | Detection Tool |
|------|-------------|----------------|
| A01 Broken Access Control | Centralized authz checks, ownership filters | Semgrep, manual review |
| A02 Misconfig | IaC scanning, CIS benchmarks | checkov, tfsec |
| A03 Injection | Parameterized queries, input validation | Semgrep, sqlmap |
| A04 Insecure Design | Threat modeling, rate limiting | Manual review, STRIDE |
| A05 Crypto Failures | argon2/bcrypt, AES-GCM, no MD5 | Semgrep, truffleHog |
| A06 Supply Chain | npm audit, Trivy, Snyk, SBOM | Dependabot, Snyk |
| A07 Auth Failures | MFA, lockout, RS256 JWT | OWASP ZAP, manual |
| A08 Integrity | Signed artifacts, no pickle | Cosign, SLSA |
| A09 Logging | Structured audit logs, SIEM | Log analysis |
| A10 Error Handling | Fail closed, never swallow | Semgrep, code review |
