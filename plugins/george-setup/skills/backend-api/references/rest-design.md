# REST API Design Reference

## URL Conventions

Use nouns, not verbs. Resources are things, not actions.

```
GOOD: GET /orders/123/items
BAD:  GET /getOrderItems?orderId=123
```

### Naming Rules

- Use plural nouns for collections: `/users`, `/orders`, `/products`
- Use kebab-case for multi-word resources: `/order-items`, `/payment-methods`
- Nest resources to express ownership: `/users/42/orders` (orders belonging to user 42)
- Limit nesting to 2 levels max. Beyond that, promote to top-level: `/order-items/99` instead of `/users/42/orders/7/items/99`
- Use query params for filtering, not path segments: `/orders?status=shipped` not `/orders/shipped`

### Action Endpoints

Some operations don't map to CRUD. Use sub-resources with POST:

```
POST /orders/123/cancel      → Cancel an order
POST /users/42/verify-email  → Trigger email verification
POST /reports/generate       → Kick off report generation
```

Why POST, not PUT: these are non-idempotent actions, not resource replacements.

## Status Codes in Practice

### Success Responses

```python
# 200 — Successful retrieval or update
@app.get("/users/{user_id}")
def get_user(user_id: str):
    user = db.find(user_id)
    if not user:
        raise HTTPException(404, detail={"code": "USER_NOT_FOUND"})
    return user  # 200 implicit

# 201 — Resource created. Always include Location header.
@app.post("/users", status_code=201)
def create_user(body: CreateUser, response: Response):
    user = db.create(body)
    response.headers["Location"] = f"/users/{user.id}"
    return user

# 204 — Successful delete. No body.
@app.delete("/users/{user_id}", status_code=204)
def delete_user(user_id: str):
    db.delete(user_id)
    return None
```

### Error Responses

Use a consistent error envelope:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Human-readable description",
    "details": [
      {"field": "email", "issue": "Invalid email format"},
      {"field": "age", "issue": "Must be >= 18"}
    ]
  }
}
```

Why `code` + `message`: clients switch on `code` (stable), humans read `message` (can change).

## Pagination

### Cursor-Based (Preferred)

Use cursor pagination for large or frequently changing datasets. Why: offset-based breaks when items are inserted/deleted between pages.

```json
GET /orders?limit=20&after=eyJpZCI6MTAwfQ

{
  "data": [...],
  "pagination": {
    "has_next": true,
    "next_cursor": "eyJpZCI6MTIwfQ",
    "has_prev": true,
    "prev_cursor": "eyJpZCI6MTAxfQ"
  }
}
```

Implementation: encode the sort key(s) as an opaque base64 cursor. Decode server-side, query with `WHERE id > :cursor_id ORDER BY id LIMIT :limit+1`. The +1 tells you if there's a next page.

### Offset-Based (Simple Cases)

Acceptable for small, static datasets (e.g., admin tables).

```json
GET /users?page=3&per_page=25

{
  "data": [...],
  "pagination": {
    "page": 3,
    "per_page": 25,
    "total": 245,
    "total_pages": 10
  }
}
```

## Filtering, Sorting, Searching

```
GET /products?category=electronics&price_min=100&price_max=500
GET /products?sort=price&order=asc
GET /products?q=wireless+headphones
```

- Use flat query params for simple filters
- Use bracket syntax for complex filters: `?filter[status]=active&filter[created_after]=2025-01-01`
- Always validate and whitelist sortable fields. Never pass user input directly to ORDER BY.

## Versioning

### URL Versioning (Recommended)

```
GET /v1/users/42
GET /v2/users/42
```

Why: explicit, easy to test in browser, simple routing. Downside: clutters URLs.

### Header Versioning (Alternative)

```
GET /users/42
Accept: application/vnd.myapi.v2+json
```

Why: clean URLs. Downside: harder to test, requires header-aware tooling.

### When to Version

- Removing or renaming a field → breaking, needs new version
- Adding an optional field → non-breaking, no version needed
- Changing a field type → breaking, needs new version
- Adding a new endpoint → non-breaking, no version needed

## HATEOAS

Include links to related actions and resources:

```json
{
  "id": "order-123",
  "status": "pending",
  "_links": {
    "self": {"href": "/orders/order-123"},
    "cancel": {"href": "/orders/order-123/cancel", "method": "POST"},
    "items": {"href": "/orders/order-123/items"},
    "customer": {"href": "/users/user-42"}
  }
}
```

Why: clients discover available actions instead of hardcoding URLs. Reduces coupling between client and server.

Pragmatic approach: include `_links` on detail endpoints. Skip on list endpoints unless clients need it — it adds payload size.

## Content Negotiation

Always return `Content-Type: application/json`. Accept `application/json` in requests. Support `application/x-www-form-urlencoded` only for legacy integrations.

For file uploads, accept `multipart/form-data`. Return the created resource as JSON, not the file.

## Request/Response Headers

```
# Request
Authorization: Bearer <token>
Content-Type: application/json
Accept: application/json
X-Request-ID: <uuid>           # Client-generated correlation ID
X-Idempotency-Key: <uuid>     # For POST requests

# Response
Content-Type: application/json
X-Request-ID: <echo back>
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 42
X-RateLimit-Reset: 1709654400
Location: /resources/new-id    # On 201 Created
Retry-After: 30                # On 429 or 503
```

## Bulk Operations

For batch creates/updates, accept an array and return per-item results:

```json
POST /users/bulk

Request:
{"items": [{"name": "Alice"}, {"name": ""}]}

Response (207 Multi-Status):
{
  "results": [
    {"status": 201, "data": {"id": "u1", "name": "Alice"}},
    {"status": 400, "error": {"code": "VALIDATION_FAILED", "field": "name"}}
  ]
}
```

Why 207: some items may succeed while others fail. Returning 200 or 400 for the whole batch loses information.
