# Webhook Patterns Reference

## Webhook Design Fundamentals

### Event Naming Convention

Use `resource.action` format in past tense. Be specific and consistent:

```
user.created          payment.succeeded       subscription.canceled
user.updated          payment.failed          subscription.renewed
user.deleted          payment.refunded        invoice.created
order.placed          charge.disputed         invoice.payment_failed
order.fulfilled       charge.captured         file.uploaded
order.canceled        charge.expired          file.processed
```

Rules:
- Always past tense (the event already happened)
- Resource before action (`payment.failed` not `failed.payment`)
- Use dots not underscores for hierarchy
- Version the event type when payload shape changes: `payment.succeeded.v2`

### Standard Payload Structure

```typescript
interface WebhookEvent<T = unknown> {
  id: string;              // UUID — unique per event, used for deduplication
  type: string;            // e.g. "payment.succeeded"
  version: string;         // e.g. "2024-01-01" — API version that produced this event
  timestamp: string;       // ISO 8601, UTC
  idempotencyKey: string;  // UUID — stable across retries of the same logical event
  livemode: boolean;       // false in test/sandbox environments
  data: T;                 // The resource snapshot at time of event
  previousData?: Partial<T>; // For update events: what changed
}

// Example
const event: WebhookEvent<Payment> = {
  id: 'evt_01HN8K2F3G4J5L6M7N8P9Q0R1S',
  type: 'payment.succeeded',
  version: '2024-11-01',
  timestamp: '2024-11-15T14:32:00.000Z',
  idempotencyKey: 'idem_01HN8K2F3G4J5L6M7N8P9Q0R1S',
  livemode: true,
  data: { id: 'pay_123', amount: 5000, currency: 'usd', status: 'succeeded' },
};
```

### Versioning Strategy

Two common approaches:

**Date-based versions** (Stripe model): `version: '2024-11-01'`. Breaking changes create a new date version. Each webhook subscription can be pinned to a version.

**Explicit v1/v2** in event type: `payment.succeeded.v1` vs `payment.succeeded.v2`. Simpler to route, harder to manage many event types.

Recommendation: Date-based versions with per-subscription pinning. Add a `webhookApiVersion` field to subscription records.

---

## HMAC-SHA256 Signature Verification

### Complete Implementation

```typescript
import crypto from 'crypto';

interface SignatureVerificationOptions {
  payload: string | Buffer;    // Raw request body — NEVER use parsed JSON
  signature: string;           // From X-Webhook-Signature header
  secret: string;              // Shared secret stored in DB for this subscription
  timestampHeader: string;     // From X-Webhook-Timestamp header (unix seconds)
  toleranceSeconds?: number;   // Default: 300 (5 minutes)
}

function verifyWebhookSignature(opts: SignatureVerificationOptions): boolean {
  const {
    payload,
    signature,
    secret,
    timestampHeader,
    toleranceSeconds = 300,
  } = opts;

  // 1. Validate timestamp to prevent replay attacks
  const timestamp = parseInt(timestampHeader, 10);
  if (isNaN(timestamp)) return false;

  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - timestamp) > toleranceSeconds) {
    throw new Error(`Webhook timestamp too old: ${now - timestamp}s drift`);
  }

  // 2. Reconstruct the signed payload (timestamp.body)
  const signedPayload = `${timestamp}.${payload}`;

  // 3. Compute expected HMAC-SHA256
  const expected = crypto
    .createHmac('sha256', secret)
    .update(signedPayload, 'utf8')
    .digest('hex');

  // 4. Timing-safe comparison — prevents timing attacks
  const expectedBuf = Buffer.from(expected, 'hex');
  const receivedBuf = Buffer.from(signature.replace(/^sha256=/, ''), 'hex');

  if (expectedBuf.length !== receivedBuf.length) return false;

  return crypto.timingSafeEqual(expectedBuf, receivedBuf);
}
```

### Express Middleware

```typescript
import express from 'express';

// CRITICAL: Use raw body parser for webhook routes — json() parser destroys signature verification
export const webhookRawBody = express.raw({ type: 'application/json' });

// Middleware that verifies and attaches parsed event
export function webhookAuth(getSecret: (subscriptionId: string) => Promise<string>) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const signature = req.headers['x-webhook-signature'] as string;
    const timestamp = req.headers['x-webhook-timestamp'] as string;
    const subscriptionId = req.headers['x-webhook-subscription-id'] as string;

    if (!signature || !timestamp || !subscriptionId) {
      return res.status(401).json({ code: 'MISSING_SIGNATURE', message: 'Missing webhook headers' });
    }

    try {
      const secret = await getSecret(subscriptionId);
      const valid = verifyWebhookSignature({
        payload: req.body,           // Buffer from raw body parser
        signature,
        secret,
        timestampHeader: timestamp,
      });

      if (!valid) {
        return res.status(401).json({ code: 'INVALID_SIGNATURE', message: 'Signature mismatch' });
      }

      // Attach parsed event for downstream handlers
      req.webhookEvent = JSON.parse(req.body.toString());
      next();
    } catch (err) {
      if (err instanceof Error && err.message.includes('timestamp too old')) {
        return res.status(401).json({ code: 'REPLAY_DETECTED', message: err.message });
      }
      next(err);
    }
  };
}
```

---

## Delivery Guarantees

### At-Least-Once Delivery

Webhooks guarantee at-least-once delivery: a subscriber must acknowledge receipt (2xx response) or the sender will retry. This means **handlers must be idempotent**.

Sender behavior:
- Send event, start retry timer
- If 2xx received within timeout → mark delivered
- If non-2xx or timeout → retry with backoff
- Log each attempt with status

Receiver requirement: Process the event, store a record, respond 200. Heavy work goes to a queue — respond immediately.

### Idempotent Handler Pattern

```typescript
// In your database (PostgreSQL example)
// CREATE TABLE webhook_events (
//   id UUID PRIMARY KEY,           -- event.id from payload
//   type VARCHAR(100) NOT NULL,
//   processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
//   status VARCHAR(20) NOT NULL DEFAULT 'processed'
// );

async function handleWebhookEvent(event: WebhookEvent): Promise<void> {
  // Idempotency check — INSERT ... ON CONFLICT DO NOTHING
  const { rowCount } = await db.query(
    `INSERT INTO webhook_events (id, type)
     VALUES ($1, $2)
     ON CONFLICT (id) DO NOTHING`,
    [event.id, event.type]
  );

  if (rowCount === 0) {
    // Already processed — skip (idempotent)
    logger.info({ eventId: event.id }, 'Duplicate webhook event, skipping');
    return;
  }

  // Process event — now safe to run exactly once
  await processEvent(event);
}
```

### Dead Letter Queue

Failed events that exhaust retries go to a DLQ for manual inspection and replay:

```typescript
interface DeadLetterEntry {
  eventId: string;
  eventType: string;
  payload: object;
  subscriptionId: string;
  lastError: string;
  attemptCount: number;
  firstFailedAt: Date;
  lastFailedAt: Date;
}

// Store in DB for dashboard review
await db.query(
  `INSERT INTO webhook_dead_letter (event_id, event_type, payload, subscription_id, last_error, attempt_count, first_failed_at, last_failed_at)
   VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
  [event.id, event.type, event.data, subscriptionId, error.message, attemptCount, firstFailedAt]
);
```

---

## Retry Strategy

### Exponential Backoff with Jitter

```typescript
function getRetryDelay(attemptNumber: number): number {
  // Base: 1s, 2s, 4s, 8s, 16s, 32s, 64s, 128s, 256s, 512s ... max 3600s
  const baseDelay = 1000; // 1 second
  const maxDelay = 3600 * 1000; // 1 hour

  const exponential = baseDelay * Math.pow(2, attemptNumber - 1);
  const capped = Math.min(exponential, maxDelay);

  // Add ±25% jitter to avoid thundering herd
  const jitter = capped * 0.25 * (Math.random() * 2 - 1);
  return Math.round(capped + jitter);
}

// Retry schedule (approximate):
// Attempt 1: immediate
// Attempt 2: ~1s
// Attempt 3: ~2s
// Attempt 4: ~4s
// Attempt 5: ~8s
// Attempt 6: ~16s
// ...
// Attempt 20: ~1h (max)
// Total window: ~24-72h depending on max_attempts setting

const MAX_ATTEMPTS = 24; // ~24h retry window

async function scheduleRetry(webhookDelivery: WebhookDelivery): Promise<void> {
  if (webhookDelivery.attemptCount >= MAX_ATTEMPTS) {
    await moveToDeadLetter(webhookDelivery);
    await maybeDisableSubscription(webhookDelivery.subscriptionId);
    return;
  }

  const delay = getRetryDelay(webhookDelivery.attemptCount + 1);
  const nextAttemptAt = new Date(Date.now() + delay);

  await db.query(
    `UPDATE webhook_deliveries
     SET next_attempt_at = $1, status = 'pending'
     WHERE id = $2`,
    [nextAttemptAt, webhookDelivery.id]
  );
}
```

---

## Subscription Management

### Webhook Endpoint Registration

```typescript
// Schema
// CREATE TABLE webhook_subscriptions (
//   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//   user_id UUID NOT NULL REFERENCES users(id),
//   url TEXT NOT NULL,
//   events TEXT[] NOT NULL,              -- ['payment.succeeded', 'payment.failed']
//   secret TEXT NOT NULL,               -- HMAC secret, shown once at creation
//   active BOOLEAN NOT NULL DEFAULT true,
//   consecutive_failures INT DEFAULT 0, -- Circuit breaker counter
//   disabled_at TIMESTAMPTZ,
//   created_at TIMESTAMPTZ DEFAULT NOW()
// );

// CREATE TABLE webhook_delivery_log (
//   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//   subscription_id UUID NOT NULL REFERENCES webhook_subscriptions(id),
//   event_id TEXT NOT NULL,
//   event_type TEXT NOT NULL,
//   status TEXT NOT NULL,               -- 'succeeded', 'failed', 'pending'
//   http_status INT,
//   attempt_count INT NOT NULL DEFAULT 1,
//   response_body TEXT,
//   duration_ms INT,
//   last_error TEXT,
//   created_at TIMESTAMPTZ DEFAULT NOW(),
//   next_attempt_at TIMESTAMPTZ
// );
```

### Circuit Breaker — Disable on Failures

```typescript
const CIRCUIT_BREAKER_THRESHOLD = 10; // consecutive failures

async function recordDeliveryFailure(subscriptionId: string, error: string): Promise<void> {
  const result = await db.query<{ consecutive_failures: number }>(
    `UPDATE webhook_subscriptions
     SET consecutive_failures = consecutive_failures + 1
     WHERE id = $1
     RETURNING consecutive_failures`,
    [subscriptionId]
  );

  const { consecutive_failures } = result.rows[0];

  if (consecutive_failures >= CIRCUIT_BREAKER_THRESHOLD) {
    await db.query(
      `UPDATE webhook_subscriptions
       SET active = false, disabled_at = NOW()
       WHERE id = $1`,
      [subscriptionId]
    );

    // Notify the user their webhook is disabled
    await notifyWebhookDisabled(subscriptionId);
  }
}

async function recordDeliverySuccess(subscriptionId: string): Promise<void> {
  await db.query(
    `UPDATE webhook_subscriptions
     SET consecutive_failures = 0
     WHERE id = $1`,
    [subscriptionId]
  );
}
```

---

## Testing Webhooks Locally

### ngrok

```bash
# Install ngrok, then expose local port
ngrok http 3000

# Output: https://abc123.ngrok.io → localhost:3000
# Use the ngrok URL as your webhook endpoint in the sending service
```

### Webhook.site

1. Go to https://webhook.site — get a unique URL
2. Send webhooks there to inspect raw headers and body
3. Use for debugging signature issues (compare raw body vs what you compute)

### Replay from Dashboard

In your webhook dashboard, implement a "Resend" button:

```typescript
// POST /admin/webhooks/:deliveryId/resend
async function resendWebhook(deliveryId: string): Promise<void> {
  const delivery = await db.query(
    `SELECT * FROM webhook_delivery_log WHERE id = $1`,
    [deliveryId]
  );

  const event = await db.query(
    `SELECT * FROM webhook_events WHERE id = $1`,
    [delivery.rows[0].event_id]
  );

  await dispatchWebhook({
    subscriptionId: delivery.rows[0].subscription_id,
    event: event.rows[0],
    isReplay: true,   // Include X-Webhook-Replay: true header
  });
}
```

---

## Fan-Out Pattern

One event triggers delivery to multiple subscribers:

```typescript
async function fanOutEvent(event: WebhookEvent): Promise<void> {
  // Find all active subscriptions listening for this event type
  const subscriptions = await db.query(
    `SELECT id, url, secret
     FROM webhook_subscriptions
     WHERE active = true
     AND $1 = ANY(events)`,
    [event.type]
  );

  // Dispatch to all in parallel (with concurrency limit)
  const deliveries = subscriptions.rows.map(sub =>
    dispatchWebhook({ subscription: sub, event })
  );

  // Use allSettled — failure for one subscriber shouldn't block others
  const results = await Promise.allSettled(deliveries);
  results.forEach((result, i) => {
    if (result.status === 'rejected') {
      logger.error({ subscriptionId: subscriptions.rows[i].id, error: result.reason }, 'Delivery failed');
    }
  });
}
```

### Message Queue Integration

For high-volume fan-out, push to a message queue instead of dispatching synchronously:

```typescript
// When an event is created, publish to Kafka topic
await kafkaProducer.send({
  topic: 'webhook-events',
  messages: [{
    key: event.type,           // Partition by event type for ordering
    value: JSON.stringify(event),
  }],
});

// Consumer picks up and fans out to all subscribers
// This decouples event production from webhook delivery
```

---

## Complete Express Handler Example

```typescript
import express, { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { db } from '../db';
import { logger } from '../logger';

const router = express.Router();

// MUST use raw body parser — do NOT put app.use(express.json()) before webhook routes
router.post(
  '/webhooks/inbound',
  express.raw({ type: 'application/json' }),
  async (req: Request, res: Response, next: NextFunction) => {
    const signature = req.headers['x-signature'] as string;
    const timestamp = req.headers['x-timestamp'] as string;

    // 1. Acknowledge immediately — do not process inline
    // Verify signature first, then respond 200, process async
    if (!signature || !timestamp) {
      return res.status(400).json({ error: 'Missing signature headers' });
    }

    let event: WebhookEvent;
    try {
      // Verify before parsing
      const secret = process.env.WEBHOOK_SECRET!;
      const valid = verifyWebhookSignature({
        payload: req.body,
        signature,
        secret,
        timestampHeader: timestamp,
      });

      if (!valid) {
        logger.warn({ ip: req.ip }, 'Invalid webhook signature');
        return res.status(401).json({ error: 'Invalid signature' });
      }

      event = JSON.parse(req.body.toString());
    } catch (err) {
      return res.status(400).json({ error: 'Invalid payload' });
    }

    // 2. Respond 200 immediately — do not await processing
    res.status(200).json({ received: true });

    // 3. Process async (setImmediate or queue)
    setImmediate(async () => {
      try {
        // Idempotency check
        const { rowCount } = await db.query(
          `INSERT INTO webhook_events (id, type, payload)
           VALUES ($1, $2, $3)
           ON CONFLICT (id) DO NOTHING`,
          [event.id, event.type, event]
        );

        if (rowCount === 0) {
          logger.info({ eventId: event.id }, 'Duplicate event, skipping');
          return;
        }

        // Route to handler
        switch (event.type) {
          case 'payment.succeeded':
            await handlePaymentSucceeded(event.data as Payment);
            break;
          case 'payment.failed':
            await handlePaymentFailed(event.data as Payment);
            break;
          case 'subscription.canceled':
            await handleSubscriptionCanceled(event.data as Subscription);
            break;
          default:
            logger.info({ eventType: event.type }, 'Unhandled webhook event type');
        }
      } catch (err) {
        logger.error({ eventId: event.id, err }, 'Webhook processing failed');
        // Push to DLQ or retry queue
        await pushToRetryQueue(event, err as Error);
      }
    });
  }
);

export { router as webhookRouter };
```
