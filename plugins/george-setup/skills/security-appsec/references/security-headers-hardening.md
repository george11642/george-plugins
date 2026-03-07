# Security Headers & Hardening Reference

---

## HTTP Security Headers — Complete Reference

### Content-Security-Policy (CSP)

The most powerful security header. Controls which resources the browser can load.

```http
# Strict, nonce-based CSP (recommended)
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{RANDOM}' 'strict-dynamic';
  style-src 'self' 'nonce-{RANDOM}';
  img-src 'self' data: blob: https://cdn.myapp.com;
  font-src 'self' https://fonts.gstatic.com;
  connect-src 'self' https://api.myapp.com wss://api.myapp.com;
  media-src 'self';
  object-src 'none';
  frame-src 'none';
  frame-ancestors 'none';
  form-action 'self';
  base-uri 'self';
  upgrade-insecure-requests;
  block-all-mixed-content;
```

**CSP violation reporting**
```http
Content-Security-Policy-Report-Only: default-src 'self'; report-uri /csp-report
# Use report-only mode first to identify breakage before enforcing
```

**`strict-dynamic`**: Allows scripts loaded by trusted nonce-bearing scripts to also load scripts. Enables modular script loading without unsafe-inline.

**Building CSP iteratively**:
1. Deploy with `Content-Security-Policy-Report-Only` + `report-uri`
2. Monitor violations for 1-2 weeks
3. Add necessary exceptions (prefer nonce over `unsafe-inline`)
4. Switch to enforcing

---

### HSTS — HTTP Strict Transport Security

```http
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

**Values**:
- `max-age=63072000` — 2 years (minimum for preload: 1 year = 31536000)
- `includeSubDomains` — all subdomains must also support HTTPS
- `preload` — submits to browser HSTS preload lists (permanent — hard to reverse)

**Preload requirements**:
1. Valid HTTPS certificate
2. HTTP redirects to HTTPS on port 80
3. All subdomains served over HTTPS
4. `max-age >= 31536000`
5. `includeSubDomains` and `preload` both present

**Submit**: https://hstspreload.org/

---

### X-Frame-Options (superseded by CSP `frame-ancestors`)

```http
X-Frame-Options: DENY           # no framing allowed
X-Frame-Options: SAMEORIGIN     # only same origin can frame
```

**Prefer CSP `frame-ancestors`** which is more expressive. Keep X-Frame-Options for older browser support.

---

### X-Content-Type-Options

```http
X-Content-Type-Options: nosniff
```

Prevents MIME type sniffing. Browser must use declared Content-Type, not guess from content. Stops attacks like serving a JavaScript file as an image.

---

### Permissions-Policy (formerly Feature-Policy)

```http
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(),
  payment=(),
  usb=(),
  interest-cohort=(),
  accelerometer=(),
  gyroscope=(),
  magnetometer=()
```

Disable browser features your app doesn't use. Reduces attack surface if XSS occurs.

---

### Referrer-Policy

```http
Referrer-Policy: strict-origin-when-cross-origin
```

| Value | Behavior |
|-------|----------|
| `no-referrer` | Never send Referer header |
| `strict-origin` | Send only origin (not path) on HTTPS→HTTPS |
| `strict-origin-when-cross-origin` | Full URL same-origin, only origin cross-origin |
| `same-origin` | Send full URL only to same origin |

**Recommended**: `strict-origin-when-cross-origin` — balances analytics needs with privacy.

---

## Nginx Full Security Header Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name myapp.com;

    # TLS
    ssl_certificate /etc/letsencrypt/live/myapp.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myapp.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "0" always;  # disabled — rely on CSP instead
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
    # CSP set per-location or in app with nonce injection
    add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'; form-action 'self';" always;

    # Hide server info
    server_tokens off;
    more_clear_headers Server;

    # Request limits
    client_max_body_size 10m;
    client_body_timeout 30s;
    client_header_timeout 30s;
    keepalive_timeout 75s;
    send_timeout 30s;

    location / {
        proxy_pass http://app:8000;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Redirect HTTP → HTTPS
server {
    listen 80;
    server_name myapp.com;
    return 301 https://$host$request_uri;
}
```

---

## Apache Security Headers

```apache
# /etc/apache2/conf-available/security.conf
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
Header always set X-Frame-Options "DENY"
Header always set X-Content-Type-Options "nosniff"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"
Header always set Content-Security-Policy "default-src 'self'; frame-ancestors 'none';"

# Remove info headers
Header unset X-Powered-By
Header always unset X-Powered-By
ServerTokens Prod
ServerSignature Off
```

---

## CORS Hardening

```python
# FastAPI — tight CORS config
from fastapi.middleware.cors import CORSMiddleware

ALLOWED_ORIGINS = [
    "https://myapp.com",
    "https://www.myapp.com",
]
# NEVER use allow_origins=["*"] for credentialed requests

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],  # explicit
    allow_headers=["Authorization", "Content-Type", "X-CSRF-Token"],
    expose_headers=["X-Request-ID"],
    max_age=600,  # preflight cache: 10 min
)
```

```nginx
# Nginx CORS — validate Origin before setting header
map $http_origin $cors_origin {
    default "";
    "https://myapp.com" "https://myapp.com";
    "https://www.myapp.com" "https://www.myapp.com";
}

location /api/ {
    if ($cors_origin != "") {
        add_header Access-Control-Allow-Origin $cors_origin always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
        add_header Vary "Origin" always;
    }
    if ($request_method = 'OPTIONS') {
        add_header Access-Control-Max-Age 600;
        return 204;
    }
}
```

**CORS anti-patterns**:
- `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true` — browsers reject this
- Reflecting Origin without validation — any origin can make credentialed requests
- Missing `Vary: Origin` — caches may serve wrong CORS headers

---

## Cookie Security Flags

```python
# Python — set secure cookie attributes
response.set_cookie(
    key="__Host-session",
    value=session_token,
    max_age=3600,
    secure=True,       # HTTPS only
    httponly=True,     # no JS access
    samesite="lax",    # CSRF protection
    # path="/",        # __Host- prefix requires path=/
    # domain=None,     # __Host- prefix requires no domain
)
```

**Cookie prefix security**:
- `__Host-` prefix: requires `Secure`, `Path=/`, no `Domain` attribute — strongest
- `__Secure-` prefix: requires `Secure` flag — intermediate
- No prefix: weakest — can be set by subdomains

---

## Rate Limiting Patterns

```python
# Token bucket with Redis (per-user rate limiting)
import redis
import time

r = redis.Redis()

def check_rate_limit(user_id: str, max_requests: int, window_seconds: int) -> bool:
    key = f"rate:{user_id}:{int(time.time()) // window_seconds}"
    current = r.incr(key)
    if current == 1:
        r.expire(key, window_seconds * 2)
    return current <= max_requests

# Sliding window log (more accurate)
def check_sliding_window(user_id: str, max_req: int, window: int) -> bool:
    now = time.time()
    key = f"sw:{user_id}"
    pipe = r.pipeline()
    pipe.zremrangebyscore(key, 0, now - window)
    pipe.zadd(key, {str(now): now})
    pipe.zcard(key)
    pipe.expire(key, window)
    results = pipe.execute()
    return results[2] <= max_req
```

```nginx
# Nginx rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

location /api/ {
    limit_req zone=api burst=20 nodelay;
    limit_req_status 429;
}
location /login {
    limit_req zone=login burst=3;
    limit_req_status 429;
}
```

---

## Brute-Force Protection

```python
# Progressive delay + lockout
import time

def attempt_login(username: str, password: str) -> dict:
    attempts = get_failed_attempts(username)  # from Redis/DB

    # Progressive delay (2^n seconds, max 30s)
    if attempts > 3:
        delay = min(2 ** (attempts - 3), 30)
        time.sleep(delay)

    # Hard lockout after 10 failures
    if attempts >= 10:
        lockout_expiry = get_lockout_expiry(username)
        if lockout_expiry and time.time() < lockout_expiry:
            raise HTTPException(429, "Account locked. Try again later.")

    # Verify credentials
    user = db.get_user(username)
    if not user or not verify_password(password, user.password_hash):
        increment_failed_attempts(username)
        # Don't reveal whether username exists
        raise HTTPException(401, "Invalid credentials")

    reset_failed_attempts(username)
    return create_session(user)
```

---

## Security Headers Checklist

```bash
# Test with securityheaders.com or locally:
curl -I https://myapp.com | grep -i "strict\|content-security\|x-frame\|x-content\|referrer\|permissions"

# Score targets:
# Strict-Transport-Security: max-age >= 31536000 + includeSubDomains
# Content-Security-Policy: present, no unsafe-inline without nonce
# X-Frame-Options: DENY or SAMEORIGIN
# X-Content-Type-Options: nosniff
# Referrer-Policy: strict-origin-when-cross-origin or stricter
# Permissions-Policy: present, disabling unused features
```

- [ ] HSTS with preload and includeSubDomains
- [ ] CSP deployed (report-only first, then enforced)
- [ ] X-Frame-Options: DENY (or CSP frame-ancestors: none)
- [ ] X-Content-Type-Options: nosniff
- [ ] Referrer-Policy: strict-origin-when-cross-origin
- [ ] Permissions-Policy: disabling camera/mic/geolocation
- [ ] CORS: explicit allowlist, no wildcard for credentialed requests
- [ ] Cookies: Secure + HttpOnly + SameSite=Lax + __Host- prefix
- [ ] Rate limiting on all auth endpoints and sensitive APIs
- [ ] Server version headers removed
