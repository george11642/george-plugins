# API Security Reference

---

## Authentication Schemes Comparison

| Scheme | Best for | Pros | Cons |
|--------|----------|------|------|
| Bearer JWT | User sessions, microservices | Stateless, fast | Revocation hard; key compromise |
| API Keys | Machine-to-machine, SDKs | Simple, easy to revoke | No expiry by default |
| mTLS | Service-to-service, high-security | Mutual authentication, no shared secrets | Certificate management overhead |
| OAuth2 Client Credentials | B2B, service auth | Standardized, scoped | More infrastructure needed |
| HMAC signatures | Webhooks, signed requests | Tamper-evident, replay protection | Shared secret required |

---

## Bearer Token Implementation

```python
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = verify_token(token)  # see authentication-authorization.md
        user = db.get_user(payload["sub"])
        if not user or not user.is_active:
            raise HTTPException(401, "User not found or inactive")
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired", headers={"WWW-Authenticate": 'Bearer error="invalid_token"'})
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token", headers={"WWW-Authenticate": "Bearer"})
```

---

## API Key Authentication

```python
# Custom header or query param — prefer header
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")

async def verify_api_key(api_key: str = Depends(api_key_header)) -> ApiKeyRecord:
    # Hash the incoming key and look up
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()
    record = db.get_api_key_by_hash(key_hash)
    if not record:
        raise HTTPException(401, "Invalid API key")
    if record.revoked or (record.expires_at and record.expires_at < datetime.utcnow()):
        raise HTTPException(401, "API key revoked or expired")
    # Check IP allowlist if configured
    if record.allowed_ips and request.client.host not in record.allowed_ips:
        raise HTTPException(403, "IP not allowed for this API key")
    db.update_last_used(record.id)
    return record
```

**API key best practices**:
- Prefix keys with service identifier: `sk_live_...`, `pk_test_...` (helps scanners)
- Never log full API key — log prefix only
- Support scopes: `read:orders`, `write:inventory`
- Default expiry: 90 days with rotation reminder

---

## mTLS — Mutual TLS

```python
# FastAPI with mTLS — Nginx handles TLS termination and passes cert info
# Nginx config:
# ssl_verify_client on;
# ssl_client_certificate /etc/ssl/ca.crt;
# proxy_set_header X-Client-Cert $ssl_client_escaped_cert;
# proxy_set_header X-Client-Verified $ssl_client_verify;

from fastapi import Request, HTTPException
import ssl, urllib.parse
from cryptography import x509
from cryptography.hazmat.backends import default_backend

def verify_mtls(request: Request) -> str:
    verified = request.headers.get("X-Client-Verified")
    if verified != "SUCCESS":
        raise HTTPException(401, "Client certificate required")
    cert_pem = urllib.parse.unquote(request.headers.get("X-Client-Cert", ""))
    cert = x509.load_pem_x509_certificate(cert_pem.encode(), default_backend())
    # Validate CN or SAN against allowlist
    cn = cert.subject.get_attributes_for_oid(x509.NameOID.COMMON_NAME)[0].value
    if cn not in ALLOWED_SERVICE_CNS:
        raise HTTPException(403, f"Service {cn} not authorized")
    return cn
```

---

## Input Validation at API Boundaries

```python
# Every request body validated with strict schema
from pydantic import BaseModel, Field, validator
from typing import Optional

class CreateOrderRequest(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(ge=1, le=1000)  # max 1000 units
    shipping_address: str = Field(min_length=10, max_length=500)
    coupon_code: Optional[str] = Field(None, regex=r'^[A-Z0-9]{4,20}$')

    @validator("shipping_address")
    def no_html(cls, v):
        if "<" in v or ">" in v:
            raise ValueError("HTML not allowed in address")
        return v

    class Config:
        # Reject extra fields (prevents mass assignment)
        extra = "forbid"
```

**Nested JSON depth limit** — prevent deeply nested payloads (DoS vector):
```python
import json

def parse_bounded_json(body: bytes, max_depth: int = 10) -> dict:
    def check_depth(obj, depth=0):
        if depth > max_depth:
            raise ValueError("JSON too deeply nested")
        if isinstance(obj, dict):
            for v in obj.values():
                check_depth(v, depth + 1)
        elif isinstance(obj, list):
            for item in obj:
                check_depth(item, depth + 1)
    data = json.loads(body)
    check_depth(data)
    return data
```

---

## Rate Limiting — Per-User and Per-Endpoint

```python
# Tiered rate limits: different limits per API tier
RATE_LIMITS = {
    "free":       {"default": "60/min", "search": "10/min"},
    "pro":        {"default": "600/min", "search": "100/min"},
    "enterprise": {"default": "6000/min", "search": "1000/min"},
}

from slowapi import Limiter
from slowapi.util import get_remote_address

def get_user_key(request: Request) -> str:
    # Prefer user ID over IP for authenticated endpoints
    user = request.state.user if hasattr(request.state, "user") else None
    return f"user:{user.id}" if user else get_remote_address(request)

limiter = Limiter(key_func=get_user_key)

@app.get("/api/search")
@limiter.limit("10/minute", key_func=lambda req: f"search:{get_user_key(req)}")
async def search(request: Request, q: str):
    ...
```

**Rate limit response headers**:
```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1740000000
Retry-After: 30
```

---

## GraphQL Security

```python
# Depth limiting — prevent deeply nested queries (DoS)
from graphql import build_ast_schema
from graphql_depth_limit import depth_limit_validator

schema = strawberry.Schema(query=Query)
app = GraphQL(
    schema,
    validation_rules=[depth_limit_validator(max_depth=5)]
)

# Query complexity limiting
from graphql_query_complexity import QueryComplexityValidator, SimpleEstimator

app = GraphQL(
    schema,
    validation_rules=[
        QueryComplexityValidator(
            max_complexity=100,
            estimators=[SimpleEstimator(default_complexity=1)]
        )
    ]
)
```

```python
# Disable introspection in production
import strawberry
from strawberry.extensions import DisableIntrospection

schema = strawberry.Schema(
    query=Query,
    extensions=[DisableIntrospection] if not DEBUG else []
)
```

```python
# Field-level authorization
@strawberry.type
class User:
    id: strawberry.ID
    username: str

    @strawberry.field
    def email(self, info: strawberry.types.Info) -> str:
        # Only return email to the user themselves or admins
        viewer = info.context["user"]
        if viewer.id != self.id and not viewer.is_admin:
            raise PermissionError("Not authorized to view email")
        return self._email
```

**GraphQL-specific risks**:
- Introspection leaks schema → disable in production
- Batching attacks: send 1000 mutations in one request → rate limit by operation count
- N+1 queries → use DataLoader (batching)
- Circular references in types → depth limit

---

## gRPC Security

```python
# mTLS for gRPC service-to-service
import grpc

server_credentials = grpc.ssl_server_credentials(
    [(private_key, certificate_chain)],
    root_certificates=ca_cert,
    require_client_auth=True
)

# Interceptor for auth
class AuthInterceptor(grpc.ServerInterceptor):
    def intercept_service(self, continuation, handler_call_details):
        metadata = dict(handler_call_details.invocation_metadata)
        token = metadata.get("authorization", "").removeprefix("Bearer ")
        if not token or not verify_token(token):
            def abort(ignored_request, context):
                context.abort(grpc.StatusCode.UNAUTHENTICATED, "Invalid token")
            return grpc.unary_unary_rpc_method_handler(abort)
        return continuation(handler_call_details)
```

---

## Sensitive Data in URLs

**Never put in URL query params**:
- Passwords, tokens, API keys
- PII (SSN, email, phone)
- Session IDs
- Card numbers

URLs end up in: server logs, browser history, Referer headers, CDN logs, analytics tools.

```python
# WRONG
GET /api/users?api_key=sk_live_abc123&email=user@example.com

# RIGHT — tokens in headers, PII in body
POST /api/users
Authorization: Bearer sk_live_abc123
Content-Type: application/json
{"email": "user@example.com"}

# For GET requests that need filtering on sensitive fields:
# Option 1: POST with body (non-standard but common)
# Option 2: Accept header with hash/token reference
```

---

## Error Message Leakage Prevention

```python
# WRONG — leaks internal details
@app.exception_handler(Exception)
async def bad_handler(req, exc):
    return JSONResponse({
        "error": str(exc),              # may contain stack traces
        "type": type(exc).__name__,     # reveals tech stack
        "traceback": format_exc(),      # full stack trace
        "query": exc.statement if hasattr(exc, "statement") else None  # SQL query!
    })

# RIGHT — safe error responses
@app.exception_handler(Exception)
async def safe_handler(req, exc):
    request_id = req.state.request_id
    log.error("Unhandled error", exc_info=exc, request_id=request_id)
    return JSONResponse(
        {"error": "An unexpected error occurred", "request_id": request_id},
        status_code=500
    )

@app.exception_handler(ValueError)
async def validation_handler(req, exc):
    # OK to return validation details — they're expected user errors
    return JSONResponse({"error": str(exc)}, status_code=400)
```

**Safe vs unsafe to include in error responses**:
- Safe: error code, request ID, user-friendly message, field-level validation errors
- Unsafe: stack traces, SQL queries, internal service names, file paths, library versions

---

## API Versioning Security

```python
# Maintain multiple versions; sunset schedule communicated in headers
@app.get("/v1/users")
async def get_users_v1():
    # Legacy version — still supported until 2026-12-31
    response.headers["Sunset"] = "Sat, 31 Dec 2026 23:59:59 GMT"
    response.headers["Deprecation"] = "true"
    response.headers["Link"] = '</v2/users>; rel="successor-version"'
    ...

# Security fix: apply to ALL active versions simultaneously
# Do NOT leave security vulnerabilities in "deprecated" versions
```

---

## API Security Checklist

- [ ] Authentication on every endpoint (no forgotten public endpoints)
- [ ] Rate limiting: per-user and per-endpoint
- [ ] Request body size limits (prevent multi-GB uploads)
- [ ] JSON depth/complexity limits
- [ ] Input validation with strict schemas at every boundary
- [ ] Sensitive data never in URLs or logs
- [ ] Error responses: safe messages only; no stack traces or internals
- [ ] GraphQL: introspection disabled, depth limited, query cost limited
- [ ] API versioning: security fixes applied to all active versions
- [ ] HTTPS everywhere; mTLS for service-to-service
- [ ] API keys: hashed at rest, scoped, expiring, with rotation
- [ ] CORS: explicit allowlist, Vary: Origin header present
