# Authentication & Authorization Reference

---

## Password Hashing

### bcrypt vs argon2 — Use argon2id for new systems

```python
# argon2 (recommended — memory-hard, GPU-resistant)
from argon2 import PasswordHasher
ph = PasswordHasher(
    time_cost=3,        # iterations
    memory_cost=65536,  # 64 MB RAM
    parallelism=4,
    hash_len=32,
    salt_len=16
)
hash = ph.hash(password)
ph.verify(hash, password)  # raises VerifyMismatchError on failure

# bcrypt (legacy systems, still acceptable)
import bcrypt
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12))
bcrypt.checkpw(password.encode(), hashed)
```

**Never use**: MD5, SHA1, SHA256, SHA512 alone (without salt + iterations), scrypt with weak params.

**Work factor guidance**: argon2id with 64MB/3 iterations or bcrypt rounds=12 takes ~100-300ms. Adjust to keep under 500ms on your hardware.

---

## JWT — JSON Web Tokens

### Algorithm choice

| Algorithm | Type | Use case |
|-----------|------|----------|
| HS256 | Symmetric (HMAC) | Single-service (secret shared between issuer and verifier) |
| RS256 | Asymmetric (RSA) | Multi-service (public key distribution) |
| ES256 | Asymmetric (ECDSA) | Multi-service, smaller tokens |

**Rule**: If issuer != verifier → use RS256 or ES256. HS256 only when the same app signs and verifies.

```python
import jwt
from cryptography.hazmat.primitives import serialization
from datetime import datetime, timedelta, timezone
from uuid import uuid4

# Issue token (RS256)
def create_token(user_id: str, roles: list[str]) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({
        "sub": str(user_id),
        "iss": "https://auth.myapp.com",
        "aud": "https://api.myapp.com",
        "exp": now + timedelta(hours=1),
        "iat": now,
        "jti": str(uuid4()),  # unique token ID for blacklisting
        "roles": roles
    }, private_key, algorithm="RS256")

# Verify token
def verify_token(token: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience="https://api.myapp.com",
            issuer="https://auth.myapp.com",
            options={"require": ["exp", "iat", "sub", "jti"]}
        )
        # Check blacklist (Redis)
        if redis.get(f"revoked_jti:{payload['jti']}"):
            raise jwt.InvalidTokenError("Token revoked")
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(401, f"Invalid token: {e}")
```

### Token rotation pattern
```python
# Short-lived access token (15 min) + long-lived refresh token (7 days)
# Refresh token stored as httpOnly cookie or hashed in DB

def refresh_access_token(refresh_token: str) -> dict:
    # 1. Verify refresh token signature
    # 2. Check refresh token not revoked in DB
    # 3. Issue new access token
    # 4. Optionally rotate refresh token (refresh token rotation)
    old_rt = db.get_refresh_token(refresh_token)
    if not old_rt or old_rt.revoked:
        # Possible reuse attack — revoke all tokens for this user
        db.revoke_all_user_tokens(old_rt.user_id)
        raise HTTPException(401, "Refresh token reuse detected")
    db.revoke_refresh_token(refresh_token)
    new_access = create_token(old_rt.user_id, old_rt.roles)
    new_refresh = create_refresh_token(old_rt.user_id)
    return {"access_token": new_access, "refresh_token": new_refresh}
```

### Token blacklisting
```python
# On logout or password change — store jti in Redis with TTL matching token expiry
def revoke_token(jti: str, exp: int):
    ttl = exp - int(datetime.now(timezone.utc).timestamp())
    if ttl > 0:
        redis.setex(f"revoked_jti:{jti}", ttl, "1")
```

---

## OAuth2 / OIDC

### Authorization Code + PKCE (public clients: SPAs, mobile)

```python
import hashlib, base64, secrets

# Client-side: generate PKCE
code_verifier = secrets.token_urlsafe(64)  # 43-128 chars
code_challenge = base64.urlsafe_b64encode(
    hashlib.sha256(code_verifier.encode()).digest()
).rstrip(b"=").decode()

# Step 1: Redirect to auth server
auth_url = (
    f"https://auth.provider.com/authorize"
    f"?response_type=code"
    f"&client_id={CLIENT_ID}"
    f"&redirect_uri={REDIRECT_URI}"
    f"&scope=openid profile email"
    f"&state={secrets.token_urlsafe(32)}"  # CSRF protection
    f"&code_challenge={code_challenge}"
    f"&code_challenge_method=S256"
)

# Step 2: Exchange code for tokens (server-side)
token_response = requests.post("https://auth.provider.com/token", data={
    "grant_type": "authorization_code",
    "code": auth_code,
    "redirect_uri": REDIRECT_URI,
    "client_id": CLIENT_ID,
    "client_secret": CLIENT_SECRET,  # confidential clients only
    "code_verifier": code_verifier
})
```

**State parameter**: Always validate it matches what was sent — prevents CSRF on callback.

**PKCE S256**: Mandatory for public clients; recommended for confidential clients too.

### ID Token validation (OIDC)
```python
from jose import jwt as jose_jwt

# Fetch JWKS from provider's .well-known/openid-configuration
jwks = requests.get("https://auth.provider.com/.well-known/jwks.json").json()

id_token_claims = jose_jwt.decode(
    id_token,
    jwks,
    algorithms=["RS256"],
    audience=CLIENT_ID,
    issuer="https://auth.provider.com"
)
# Validate: iat not too far in past, nonce matches (if used)
```

---

## Session Management

```python
# Secure session configuration (Flask example)
app.config.update(
    SESSION_COOKIE_SECURE=True,      # HTTPS only
    SESSION_COOKIE_HTTPONLY=True,    # No JavaScript access
    SESSION_COOKIE_SAMESITE="Lax",  # CSRF protection
    SESSION_COOKIE_NAME="__Host-session",  # __Host- prefix: strict
    PERMANENT_SESSION_LIFETIME=timedelta(hours=8),
)

# Session fixation prevention: regenerate session ID after login
def login_user(user):
    session.clear()          # clear old session
    session.regenerate()     # new session ID
    session["user_id"] = user.id
    session["login_at"] = datetime.utcnow().isoformat()
```

**Session storage**: Prefer server-side sessions (Redis) over client-side (signed cookies) when storing sensitive data.

**Absolute timeout**: Expire session regardless of activity (8-24 hours).
**Idle timeout**: Expire after inactivity (15-30 minutes for sensitive apps).

---

## RBAC vs ABAC

### RBAC — Role-Based Access Control
```python
ROLES = {
    "admin":   {"users:*", "billing:*", "reports:*"},
    "editor":  {"articles:read", "articles:write"},
    "viewer":  {"articles:read"},
}

def require_permission(permission: str):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, user=Depends(get_current_user), **kwargs):
            user_perms = ROLES.get(user.role, set())
            if not any(
                fnmatch(permission, p) for p in user_perms
            ):
                raise HTTPException(403, "Insufficient permissions")
            return func(*args, user=user, **kwargs)
        return wrapper
    return decorator

@app.delete("/users/{user_id}")
@require_permission("users:delete")
def delete_user(user_id: int, user=Depends(get_current_user)):
    ...
```

### ABAC — Attribute-Based Access Control
```python
# More flexible: checks attributes of subject, resource, environment
def can_access(user: User, resource: Resource, action: str) -> bool:
    # Example policy: editors can edit their own articles
    if action == "edit" and resource.type == "article":
        return user.role == "editor" and resource.author_id == user.id
    # Admins can do anything in their own org
    if user.role == "admin":
        return resource.org_id == user.org_id
    return False
```

**Choose RBAC** for: simple apps, clear role boundaries, small number of roles.
**Choose ABAC** for: multi-tenant, fine-grained, time/context-dependent access.

---

## API Keys

```python
import secrets, hashlib

# Generation: use cryptographically secure random
def create_api_key(user_id: str, name: str) -> dict:
    raw_key = f"sk_{secrets.token_urlsafe(32)}"  # prefix helps scanners
    # Store only the hash — never the plaintext
    key_hash = hashlib.sha256(raw_key.encode()).hexdigest()
    db.insert_api_key({
        "user_id": user_id,
        "name": name,
        "key_hash": key_hash,
        "prefix": raw_key[:8],  # for identification without exposing key
        "created_at": datetime.utcnow(),
        "last_used_at": None,
        "scopes": [],
    })
    return {"key": raw_key}  # Show ONCE — user must save it

# Verification
def verify_api_key(raw_key: str) -> Optional[ApiKey]:
    key_hash = hashlib.sha256(raw_key.encode()).hexdigest()
    key = db.get_api_key_by_hash(key_hash)
    if key:
        db.update_last_used(key.id)  # track usage
    return key
```

**Key rotation**: Provide rotation endpoint; support overlap period where old key still works for 7 days.

---

## MFA Patterns

```python
import pyotp, qrcode

# TOTP (Time-based One-Time Password — Google Authenticator)
def setup_totp(user_id: str) -> dict:
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    # Store secret encrypted in DB
    db.store_totp_secret(user_id, encrypt(secret))
    uri = totp.provisioning_uri(name=user.email, issuer_name="MyApp")
    return {"secret": secret, "qr_uri": uri}

def verify_totp(user_id: str, code: str) -> bool:
    secret = decrypt(db.get_totp_secret(user_id))
    totp = pyotp.TOTP(secret)
    # valid_window=1 allows 30s clock drift
    if not totp.verify(code, valid_window=1):
        return False
    # Prevent replay: check code not used in last 90s
    if redis.get(f"used_totp:{user_id}:{code}"):
        return False
    redis.setex(f"used_totp:{user_id}:{code}", 90, "1")
    return True

# Recovery codes: generate 8-10 single-use codes, store hashed
def generate_recovery_codes(user_id: str) -> list[str]:
    codes = [secrets.token_hex(10) for _ in range(10)]
    db.store_recovery_codes(user_id, [sha256(c) for c in codes])
    return codes  # Show once
```

**WebAuthn (Passkeys)**: Preferred over TOTP — phishing-resistant, no shared secret.

---

## Secure Cookie Flags Reference

| Flag | Effect | When to use |
|------|--------|-------------|
| `Secure` | HTTPS only | Always in production |
| `HttpOnly` | No JS access | Session cookies, refresh tokens |
| `SameSite=Strict` | Never sent cross-site | Admin panels |
| `SameSite=Lax` | Sent on top-level navigation | Most apps |
| `SameSite=None; Secure` | Always sent cross-site | Third-party embeds only |
| `__Host-` prefix | Forces Secure + no Domain + path=/ | Highest security |
| `__Secure-` prefix | Forces Secure flag | Secondary option |

```http
Set-Cookie: __Host-session=abc123; Secure; HttpOnly; SameSite=Lax; Path=/
```

---

## Passwordless Authentication

### Magic link
```python
def send_magic_link(email: str):
    token = secrets.token_urlsafe(32)
    # Store token hash with 15-min expiry
    redis.setex(f"magic:{hashlib.sha256(token.encode()).hexdigest()}", 900, email)
    send_email(email, f"https://app.com/auth/magic?token={token}")

def verify_magic_link(token: str) -> str:
    key = f"magic:{hashlib.sha256(token.encode()).hexdigest()}"
    email = redis.get(key)
    if not email:
        raise HTTPException(401, "Invalid or expired link")
    redis.delete(key)  # single use
    return email
```

---

## Authorization Checklist

- [ ] Every API endpoint has explicit authorization check (no default allow)
- [ ] Authorization checked server-side (never trust client claims)
- [ ] Ownership verified on all data access (not just authentication)
- [ ] Sensitive operations require re-authentication (e.g., change email/password)
- [ ] JWT: RS256 used for multi-service; `alg: none` explicitly rejected
- [ ] JWT: short expiry (15-60 min access token); JTI blacklist on revoke
- [ ] OAuth2: PKCE enforced for public clients; state parameter validated
- [ ] Sessions: regenerated after login; HttpOnly+Secure+SameSite flags set
- [ ] Passwords: argon2id or bcrypt rounds≥12; no MD5/SHA1
- [ ] API keys: hashed at rest; prefix shown for identification; rotation supported
- [ ] MFA: TOTP replay prevention; recovery codes generated and hashed
