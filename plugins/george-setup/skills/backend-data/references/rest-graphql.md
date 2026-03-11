# REST & GraphQL API Design

Consolidated from: backend-api (rest-design.md, graphql.md, api-design-patterns.md)

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

---

# GraphQL Reference

## When to Use GraphQL

Use GraphQL when clients need flexible queries across deeply nested data, when multiple client types (web, mobile, TV) need different response shapes, or when you want to reduce roundtrips for complex screens. Avoid GraphQL for simple CRUD APIs, file uploads, or when HTTP caching is critical.

## Schema Design

### Type Design Principles

Design types around business domains, not database tables. Expose what clients need, hide implementation details.

```graphql
# GOOD — domain-oriented
type Order {
  id: ID!
  status: OrderStatus!
  total: Money!
  items: [OrderItem!]!
  customer: Customer!
  placedAt: DateTime!
}

type Money {
  amount: Int!        # Store as cents to avoid float issues
  currency: Currency!
}

# BAD — database-oriented
type Order {
  id: Int!
  status_id: Int!
  total_cents: Int!
  currency_code: String!
  customer_id: Int!
  created_at: String!
}
```

### Input Types

Always use input types for mutations. Never reuse output types as inputs.

```graphql
input CreateOrderInput {
  customerId: ID!
  items: [OrderItemInput!]!
  note: String
}

input OrderItemInput {
  productId: ID!
  quantity: Int!
}

type CreateOrderPayload {
  order: Order
  errors: [UserError!]!
}

type UserError {
  field: [String!]!
  message: String!
  code: ErrorCode!
}
```

Why separate payload type: mutations can partially succeed. Return both the result and structured errors so clients handle both paths.

### Naming Conventions

- Types: PascalCase (`OrderItem`, `PaymentMethod`)
- Fields: camelCase (`placedAt`, `totalAmount`)
- Enums: SCREAMING_SNAKE (`ORDER_PLACED`, `PAYMENT_FAILED`)
- Mutations: verb + noun (`createOrder`, `cancelSubscription`)
- Queries: noun for single (`order`), plural for lists (`orders`)

## Resolvers

### Keep Resolvers Thin

Resolvers are controllers — they parse input, call business logic, format output. Never put business logic in resolvers.

```python
# GOOD
@strawberry.mutation
def create_order(self, input: CreateOrderInput) -> CreateOrderPayload:
    try:
        order = order_service.create(input.customer_id, input.items)
        return CreateOrderPayload(order=order, errors=[])
    except ValidationError as e:
        return CreateOrderPayload(order=None, errors=e.to_user_errors())

# BAD — business logic in resolver
@strawberry.mutation
def create_order(self, input: CreateOrderInput) -> CreateOrderPayload:
    if not db.customers.exists(input.customer_id):
        raise Error("Customer not found")
    total = sum(db.products.get(i.product_id).price * i.quantity for i in input.items)
    order = db.orders.insert(customer_id=input.customer_id, total=total)
    # ... 40 more lines of logic
```

### N+1 Prevention with DataLoader

The biggest GraphQL performance trap. When resolving a list of orders, each order's `customer` field triggers a separate DB query.

```python
# WITHOUT DataLoader — N+1 queries
class OrderResolver:
    def customer(self, order):
        return db.customers.get(order.customer_id)  # Called N times

# WITH DataLoader — 1 batch query
customer_loader = DataLoader(
    batch_fn=lambda ids: db.customers.get_many(ids)
)

class OrderResolver:
    def customer(self, order):
        return customer_loader.load(order.customer_id)  # Batched automatically
```

DataLoader batches all `.load()` calls within a single event loop tick into one batch function call. Create a new DataLoader instance per request to avoid cache leaks between users.

## Pagination — Relay Connection Pattern

```graphql
type Query {
  orders(first: Int, after: String, last: Int, before: String): OrderConnection!
}

type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
  totalCount: Int
}

type OrderEdge {
  node: Order!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

Why Relay connections: standardized pattern that every GraphQL client understands. Cursors enable stable pagination. `edges` allow per-edge metadata (e.g., `role` in a user-team relationship).

## Subscriptions

Use for real-time updates: notifications, live dashboards, collaborative editing.

```graphql
type Subscription {
  orderStatusChanged(orderId: ID!): Order!
  newMessage(channelId: ID!): Message!
}
```

Implementation: prefer WebSocket transport (graphql-ws protocol). For simple use cases, consider SSE instead — simpler infrastructure, works through proxies.

Do not use subscriptions for: polling replacements (use queries + client-side polling), bulk data sync (use REST + pagination), fire-and-forget notifications (use webhooks).

## Federation (Apollo Federation)

Split a monolithic schema across services. Each service owns its types.

```graphql
# Orders service — owns Order type
type Order @key(fields: "id") {
  id: ID!
  status: OrderStatus!
  items: [OrderItem!]!
  customer: Customer!  # Reference to Users service
}

extend type Customer @key(fields: "id") {
  id: ID! @external
  orders: [Order!]!   # Extend Customer with orders
}

# Users service — owns Customer type
type Customer @key(fields: "id") {
  id: ID!
  name: String!
  email: String!
}
```

The gateway composes schemas and routes queries to the right service. Each service resolves its own fields + provides `__resolveReference` for cross-service lookups.

### Federation Rules

- One service owns each type. Other services extend it.
- Use `@key` to define how types are referenced across services.
- Keep cross-service joins shallow (1 level). Deep joins create performance nightmares.
- Always implement `__resolveReference` with DataLoader.

## Security

- **Depth limiting.** Reject queries deeper than N levels (usually 7-10). Why: deeply nested queries can exponentially multiply DB queries.
- **Query complexity.** Assign cost to each field, reject queries exceeding a budget. Why: a single query can request millions of records.
- **Introspection.** Disable in production. Why: exposes your entire schema to attackers.
- **Persisted queries.** In production, only allow pre-registered query hashes. Why: prevents arbitrary query injection.

```python
# Complexity example
schema = strawberry.Schema(
    query=Query,
    extensions=[
        QueryDepthLimiter(max_depth=10),
        QueryComplexityLimiter(max_complexity=500),
    ]
)
```

## Error Handling

Return errors in the response payload, not as GraphQL-level errors. GraphQL errors are for infrastructure issues (auth failure, malformed query). Business errors belong in the mutation payload.

```graphql
# GOOD — errors in payload
mutation {
  createOrder(input: {...}) {
    order { id }
    errors { field message code }
  }
}

# BAD — throwing GraphQL errors for business logic
# This breaks client error handling patterns
```
