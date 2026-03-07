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
