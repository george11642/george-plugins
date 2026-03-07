# Microservices Reference

## Service Boundaries

### Finding Boundaries

Use Domain-Driven Design bounded contexts. Each service owns one business capability and its data.

```
GOOD boundaries (independent lifecycle):
  - OrderService: order creation, status, fulfillment
  - PaymentService: charges, refunds, payment methods
  - InventoryService: stock levels, reservations
  - NotificationService: email, SMS, push

BAD boundaries (too coupled):
  - OrderPaymentService (two domains, forced co-deployment)
  - UserProfileAvatarService (too granular, overhead > value)
```

### The Litmus Test

Ask: "Can this service be deployed independently without coordinating with other teams?" If no, merge the services or redesign the boundary.

### Database Per Service

Each service owns its database. No shared databases. Why:
- Schema changes in one service cannot break another
- Services can choose the best storage for their domain (SQL, document, graph)
- Independent scaling of storage

Cross-service data access happens through APIs, never direct DB queries.

## Communication Patterns

### Synchronous — HTTP/gRPC

Use for operations where the caller needs an immediate response.

```python
# Service A calls Service B synchronously
class OrderService:
    def create_order(self, order_data):
        # Check inventory — need answer NOW
        available = inventory_client.check_stock(order_data.items)
        if not available:
            raise InsufficientStockError()

        order = self.repo.create(order_data)

        # Charge payment — need answer NOW
        payment = payment_client.charge(order.total, order.payment_method)
        if not payment.success:
            self.repo.cancel(order.id)
            raise PaymentFailedError()

        return order
```

Always add: timeout (2-5s), retry with backoff, circuit breaker. Without these, one slow service takes down the entire chain.

### Asynchronous — Events

Use for operations where the caller does NOT need an immediate response, or where multiple services react to the same event.

```python
# Service A publishes event, doesn't wait
class OrderService:
    def complete_order(self, order_id):
        order = self.repo.mark_completed(order_id)
        # Multiple services react independently
        self.event_bus.publish("order.completed", {
            "order_id": order.id,
            "customer_id": order.customer_id,
            "total": order.total,
            "items": order.items,
        })
        # NotificationService sends email
        # AnalyticsService updates dashboards
        # LoyaltyService awards points
```

## Saga Pattern

Manage distributed transactions across services. There is no distributed ACID — use sagas to coordinate and compensate.

### Choreography (Event-Driven)

Each service listens for events and reacts. No central coordinator.

```
OrderService: creates order → publishes order.created
PaymentService: hears order.created → charges card → publishes payment.completed
InventoryService: hears payment.completed → reserves stock → publishes stock.reserved
OrderService: hears stock.reserved → marks order confirmed

COMPENSATION (payment fails):
PaymentService: publishes payment.failed
OrderService: hears payment.failed → cancels order
```

Pros: simple, decoupled. Cons: hard to track overall flow, debugging requires correlating events across services.

### Orchestration (Central Coordinator)

A saga orchestrator directs each step and handles failures.

```python
class CreateOrderSaga:
    steps = [
        SagaStep(
            action=lambda ctx: payment_service.charge(ctx.order),
            compensation=lambda ctx: payment_service.refund(ctx.payment_id),
        ),
        SagaStep(
            action=lambda ctx: inventory_service.reserve(ctx.order.items),
            compensation=lambda ctx: inventory_service.release(ctx.reservation_id),
        ),
        SagaStep(
            action=lambda ctx: order_service.confirm(ctx.order.id),
            compensation=lambda ctx: order_service.cancel(ctx.order.id),
        ),
    ]

    def execute(self, order):
        ctx = SagaContext(order=order)
        for i, step in enumerate(self.steps):
            try:
                step.action(ctx)
            except Exception:
                # Compensate all completed steps in reverse
                for completed_step in reversed(self.steps[:i]):
                    completed_step.compensation(ctx)
                raise SagaFailed()
```

Pros: clear flow, easy to debug, centralized error handling. Cons: orchestrator is a single point of failure, tighter coupling.

Use orchestration when: >3 steps, complex compensation logic, need visibility. Use choreography when: 2-3 steps, simple flows, services are truly independent.

## CQRS (Command Query Responsibility Segregation)

Separate write models (commands) from read models (queries). Why: reads and writes have different performance characteristics, scaling needs, and data shapes.

```python
# WRITE side — normalized, consistent
class OrderCommandHandler:
    def handle_create_order(self, cmd):
        order = Order.create(cmd.customer_id, cmd.items)
        self.repo.save(order)
        self.event_bus.publish("order.created", order.to_event())

# READ side — denormalized, fast
class OrderQueryHandler:
    def get_order_summary(self, order_id):
        # Reads from a denormalized view optimized for this query
        return self.read_db.query(
            "SELECT * FROM order_summaries WHERE id = ?", order_id
        )

# Event handler keeps read model in sync
class OrderProjection:
    def on_order_created(self, event):
        self.read_db.insert("order_summaries", {
            "id": event.order_id,
            "customer_name": event.customer_name,  # Denormalized
            "total": event.total,
            "item_count": len(event.items),
            "status": "created",
        })
```

When to use CQRS: read/write ratio is heavily skewed (100:1), reads need denormalized views, reads and writes scale independently. Skip CQRS for simple CRUD apps — it adds significant complexity.

## Service Discovery & Communication

### API Gateway

Single entry point for external clients. Routes requests to internal services.

```
Client → API Gateway → OrderService
                     → PaymentService
                     → UserService
```

The gateway handles: routing, authentication, rate limiting, request/response transformation, SSL termination. Keep the gateway thin — no business logic.

### Service Mesh (Istio, Linkerd)

Infrastructure layer for service-to-service communication. Handles: mTLS, retries, circuit breaking, observability — without changing application code.

Use when: >10 services, need consistent security/observability, polyglot services. Skip when: <5 services (overhead > value).

## Health Checks

Every service exposes health endpoints:

```python
@app.get("/health/live")
def liveness():
    """Am I running? Kubernetes restarts if this fails."""
    return {"status": "ok"}

@app.get("/health/ready")
def readiness():
    """Can I serve traffic? LB removes if this fails."""
    db_ok = check_db_connection()
    cache_ok = check_redis_connection()
    return {
        "status": "ok" if (db_ok and cache_ok) else "degraded",
        "checks": {"database": db_ok, "cache": cache_ok}
    }
```

### Circuit Breaker

Prevent cascading failures. When a dependency fails repeatedly, stop calling it.

```python
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=30)
def call_payment_service(order):
    response = httpx.post(f"{PAYMENT_URL}/charge", json=order.to_dict(), timeout=3.0)
    response.raise_for_status()
    return response.json()

# States: CLOSED (normal) → OPEN (failing, fast-fail) → HALF-OPEN (test one request)
```

## Deployment Patterns

- **Blue-green**: Two identical environments. Switch traffic atomically. Zero downtime. Higher cost (2x infra).
- **Canary**: Route 1-5% of traffic to new version. Monitor errors/latency. Gradually increase. Lower risk.
- **Rolling**: Replace instances one at a time. Kubernetes default. Simple but slow rollback.

## Anti-Patterns

- **Distributed monolith.** Services that must deploy together. Fix: redesign boundaries, use events instead of sync calls.
- **Shared database.** Multiple services reading/writing the same tables. Fix: database per service, expose data through APIs.
- **Sync everywhere.** Every call is HTTP request-response. Fix: use events for non-critical paths.
- **No contract testing.** Consumer and provider schemas drift apart. Fix: use Pact or similar contract testing tools.
- **Missing correlation IDs.** Cannot trace a request across services. Fix: generate at the gateway, propagate through all services.
