# Secure Coding Patterns Reference

---

## Input Validation

### Allowlist vs Denylist
**Always prefer allowlist** — define what IS allowed, reject everything else.

```python
import re
from pydantic import BaseModel, validator, constr

# Denylist (weak) — attacker finds bypass
def validate_username_bad(username: str) -> bool:
    banned = ["<", ">", "'", '"', ";", "--"]
    return not any(c in username for c in banned)

# Allowlist (strong) — only permit known-good characters
USERNAME_RE = re.compile(r'^[a-zA-Z0-9_-]{3,32}$')
def validate_username(username: str) -> bool:
    return bool(USERNAME_RE.match(username))

# Schema validation with Pydantic (Python)
class CreateUserRequest(BaseModel):
    username: constr(regex=r'^[a-zA-Z0-9_-]{3,32}$')
    email: EmailStr
    age: int = Field(ge=0, le=150)
    role: Literal["user", "editor"]  # enum — no arbitrary values
```

```typescript
// Zod schema validation (TypeScript)
import { z } from "zod";
const CreateUserSchema = z.object({
  username: z.string().regex(/^[a-zA-Z0-9_-]{3,32}$/),
  email: z.string().email(),
  age: z.number().int().min(0).max(150),
  role: z.enum(["user", "editor"]),
});
type CreateUserRequest = z.infer<typeof CreateUserSchema>;
```

**Validation locations**: Validate at every trust boundary — HTTP request → controller → service → DB. Don't rely on frontend validation alone.

---

## SQL Injection Prevention

```python
# VULNERABLE — string interpolation
def get_user_bad(username: str):
    query = f"SELECT * FROM users WHERE username = '{username}'"
    return db.execute(query)

# SECURE — parameterized query (psycopg2)
def get_user(username: str):
    return db.execute("SELECT * FROM users WHERE username = %s", (username,))

# SECURE — SQLAlchemy ORM
from sqlalchemy.orm import Session
def get_user_orm(session: Session, username: str):
    return session.query(User).filter(User.username == username).first()

# SECURE — SQLAlchemy Core with bound params
from sqlalchemy import text
def get_user_core(conn, username: str):
    return conn.execute(text("SELECT * FROM users WHERE username = :name"), {"name": username})
```

```javascript
// Node.js — pg library
const { rows } = await client.query(
  "SELECT * FROM users WHERE username = $1",
  [username]  // parameterized
);

// Knex.js ORM
const user = await db("users").where("username", username).first();
```

**Dynamic ORDER BY** (common injection vector):
```python
ALLOWED_COLUMNS = {"created_at", "username", "email"}
ALLOWED_DIRS = {"ASC", "DESC"}
def get_users_sorted(column: str, direction: str):
    if column not in ALLOWD_COLUMNS or direction not in ALLOWED_DIRS:
        raise ValueError("Invalid sort parameters")
    # Safe to use in query since we validated against allowlist
    return db.execute(f"SELECT * FROM users ORDER BY {column} {direction}")
```

---

## XSS Prevention

```python
# Server-side output encoding
import html
def render_comment(comment: str) -> str:
    return html.escape(comment)  # &lt; &gt; &amp; etc.
```

```javascript
// React — JSX auto-escapes by default
const Comment = ({ text }) => <div>{text}</div>;  // safe

// DANGEROUS — bypasses escaping
const Comment = ({ html }) => <div dangerouslySetInnerHTML={{ __html: html }} />;

// If dangerouslySetInnerHTML is needed — sanitize first
import DOMPurify from "dompurify";
const Comment = ({ html }) => (
  <div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(html) }} />
);
```

### Content Security Policy
```http
# Strict CSP — prevents inline scripts and unauthorized sources
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{RANDOM_PER_REQUEST}';
  style-src 'self' 'nonce-{RANDOM_PER_REQUEST}';
  img-src 'self' data: https://cdn.myapp.com;
  font-src 'self';
  connect-src 'self' https://api.myapp.com;
  frame-ancestors 'none';
  form-action 'self';
  base-uri 'self';
  upgrade-insecure-requests;
```

**Nonce-based CSP** (preferred over hash or `unsafe-inline`):
```python
import secrets
def get_csp_nonce() -> str:
    return secrets.token_hex(16)

# Add to response header and inject into script tags
nonce = get_csp_nonce()
response.headers["Content-Security-Policy"] = f"script-src 'nonce-{nonce}'"
# In template: <script nonce="{{ nonce }}">...</script>
```

---

## CSRF Prevention

```python
# SameSite cookies are the primary defense (see security-headers-hardening.md)
# Double-submit cookie pattern as secondary defense

import secrets, hmac, hashlib

def generate_csrf_token(session_id: str) -> str:
    secret = app.config["CSRF_SECRET"]
    return hmac.new(secret.encode(), session_id.encode(), hashlib.sha256).hexdigest()

def validate_csrf(request, session_id: str):
    token_from_header = request.headers.get("X-CSRF-Token")
    expected = generate_csrf_token(session_id)
    if not hmac.compare_digest(token_from_header or "", expected):
        raise HTTPException(403, "CSRF validation failed")
```

```javascript
// Frontend: include CSRF token in all state-changing requests
const csrfToken = document.cookie.match(/csrftoken=([^;]+)/)?.[1];
fetch("/api/delete", {
  method: "POST",
  headers: { "X-CSRFToken": csrfToken, "Content-Type": "application/json" },
  body: JSON.stringify({ id: 123 })
});
```

**When SameSite=Lax/Strict is set**: CSRF tokens may be redundant for browser-initiated requests, but keep them for defense-in-depth and API clients.

---

## Path Traversal Prevention

```python
import os
from pathlib import Path

UPLOAD_DIR = Path("/var/app/uploads").resolve()

def get_file(filename: str) -> Path:
    # Normalize and check file stays within allowed directory
    safe_path = (UPLOAD_DIR / filename).resolve()
    if not str(safe_path).startswith(str(UPLOAD_DIR)):
        raise ValueError("Path traversal detected")
    return safe_path

# Usage
try:
    path = get_file(user_input)  # ../../etc/passwd → rejected
except ValueError:
    return HTTPException(400, "Invalid filename")
```

---

## XXE (XML External Entity) Injection

```python
# VULNERABLE — default XML parsers allow external entities
import xml.etree.ElementTree as ET
tree = ET.parse(user_uploaded_file)  # may be vulnerable

# SECURE — defusedxml
import defusedxml.ElementTree as ET
try:
    tree = ET.parse(user_uploaded_file)
except ET.ParseError:
    raise HTTPException(400, "Invalid XML")
```

```java
// Java — disable external entities
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setExpandEntityReferences(false);
```

---

## SSRF Mitigations

```python
import ipaddress, socket
from urllib.parse import urlparse

ALLOWED_SCHEMES = {"https", "http"}
# Private/link-local IP ranges to block
BLOCKED_CIDRS = [
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"),  # link-local/metadata
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
]

def is_safe_url(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme not in ALLOWED_SCHEMES:
        return False
    # Resolve DNS and check all returned IPs
    try:
        infos = socket.getaddrinfo(parsed.hostname, None)
    except socket.gaierror:
        return False
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        for blocked in BLOCKED_CIDRS:
            if ip in blocked:
                return False
    return True
```

**Cloud metadata endpoints to always block**:
- `169.254.169.254` (AWS/GCP/Azure EC2 metadata)
- `fd00:ec2::254` (AWS IPv6 metadata)
- `metadata.google.internal`

---

## Mass Assignment Protection

```python
# VULNERABLE — bind all request fields to model
@app.post("/users")
def create_user(data: dict, db: Session):
    user = User(**data)  # attacker can set is_admin=True
    db.add(user)

# SECURE — explicit allowlist of settable fields
class CreateUserInput(BaseModel):
    username: str
    email: str
    # is_admin, role, created_at NOT included

@app.post("/users")
def create_user(data: CreateUserInput, db: Session):
    user = User(
        username=data.username,
        email=data.email,
        is_admin=False,  # explicitly set server-side
        role="user"
    )
    db.add(user)
```

```javascript
// Express — use pick() for allowed fields only
const allowedFields = ["username", "email", "bio"];
const userData = _.pick(req.body, allowedFields);
const user = new User(userData);
```

---

## Secure File Upload

```python
import magic  # python-magic for MIME type detection
import hashlib
from PIL import Image
import io

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

def validate_and_store_upload(file_bytes: bytes, claimed_name: str) -> str:
    # 1. Check size
    if len(file_bytes) > MAX_FILE_SIZE:
        raise ValueError("File too large")

    # 2. Detect MIME type from content (not file extension or Content-Type header)
    detected_mime = magic.from_buffer(file_bytes, mime=True)
    if detected_mime not in ALLOWED_MIME_TYPES:
        raise ValueError(f"File type not allowed: {detected_mime}")

    # 3. For images: re-encode to strip EXIF/metadata and validate image integrity
    if detected_mime.startswith("image/"):
        img = Image.open(io.BytesIO(file_bytes))
        img.verify()  # raises if invalid/corrupted
        # Re-encode to strip embedded payloads
        output = io.BytesIO()
        img = Image.open(io.BytesIO(file_bytes))  # reopen after verify
        img.save(output, format=img.format)
        file_bytes = output.getvalue()

    # 4. Generate safe filename (never use original)
    content_hash = hashlib.sha256(file_bytes).hexdigest()
    ext_map = {"image/jpeg": ".jpg", "image/png": ".png", ...}
    safe_name = f"{content_hash}{ext_map.get(detected_mime, '.bin')}"

    # 5. Store OUTSIDE web root or in object storage (S3), not /var/www/html
    store_to_s3(safe_name, file_bytes)
    return safe_name
```

**Never**: serve uploaded files from the same origin as the app — use a separate subdomain or CDN. **Never**: allow SVG uploads without sanitization (can contain JavaScript).

---

## Secure Coding Checklist

- [ ] All inputs validated against allowlist schema at trust boundary
- [ ] SQL queries use parameterized statements or ORM (no string interpolation)
- [ ] Output HTML-encoded before rendering in browser
- [ ] CSP header with nonce-based script allowlist
- [ ] CSRF: SameSite=Lax cookies + CSRF token for state-changing endpoints
- [ ] File uploads: MIME detected from content, re-encoded, stored outside webroot
- [ ] Path traversal: resolved path verified to stay within allowed directory
- [ ] XML parsing uses defusedxml or external entities disabled
- [ ] SSRF: outbound URLs validated against IP allowlist/blocklist after DNS resolution
- [ ] Mass assignment: explicit field allowlist in all request schemas
- [ ] Dynamic query parts (ORDER BY column) validated against enum allowlist
