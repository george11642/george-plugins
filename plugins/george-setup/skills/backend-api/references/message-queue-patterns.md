# Message Queue Patterns Reference

## Kafka

### Core Concepts

**Topic**: A named, append-only log. Messages are immutable once written. Topics are split into partitions for parallelism.

**Partition**: The unit of parallelism and ordering. Messages within a partition are strictly ordered. Across partitions, no ordering guarantee.

**Consumer Group**: A group of consumers that coordinate to consume a topic. Each partition is assigned to exactly one consumer in the group at a time. Adding consumers to a group scales throughput.

**Offset**: Position of a message within a partition. Consumers commit offsets to track progress. On restart, resume from last committed offset.

```
Topic: "payments"
  Partition 0: [msg1, msg2, msg5, msg8, ...]   ← Consumer A
  Partition 1: [msg3, msg6, msg9, ...]          ← Consumer B
  Partition 2: [msg4, msg7, msg10, ...]         ← Consumer C

Consumer Group "payment-processors": A, B, C share the partitions
Consumer Group "payment-analytics":  D reads all partitions independently
```

### Partition Key Selection

The partition key determines which partition a message lands in. Messages with the same key always go to the same partition (ordering guarantee per key).

```typescript
// Good: partition by userId — all events for a user are ordered
await producer.send({
  topic: 'user-events',
  messages: [{ key: userId, value: JSON.stringify(event) }],
});

// Good: partition by orderId — all order events are ordered
await producer.send({
  topic: 'order-events',
  messages: [{ key: orderId, value: JSON.stringify(event) }],
});

// Bad: partition by event type — creates hotspots if one type dominates
// Bad: null key — random partition, no ordering guarantee

// Avoid hotspots: if userId distribution is uneven, use userId mod N
// to force even distribution across N partitions
const partitionKey = `${userId}-${parseInt(userId) % numPartitions}`;
```

### Consumer Group Offset Management

```typescript
import { Kafka, EachMessagePayload } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'payment-service',
  brokers: [process.env.KAFKA_BROKER!],
  ssl: true,
  sasl: { mechanism: 'plain', username: process.env.KAFKA_USER!, password: process.env.KAFKA_PASS! },
  retry: { initialRetryTime: 300, retries: 10 },
});

const consumer = kafka.consumer({
  groupId: 'payment-processors',
  sessionTimeout: 30000,    // Time before consumer considered dead
  heartbeatInterval: 3000,  // Must be < sessionTimeout / 3
  maxBytesPerPartition: 1048576,  // 1MB per partition per fetch
});

await consumer.connect();
await consumer.subscribe({ topic: 'payments', fromBeginning: false });

await consumer.run({
  // autoCommit: true is default — commits every 5s
  // For exactly-once: disable and commit manually after processing
  autoCommit: false,
  eachMessage: async ({ topic, partition, message, heartbeat }: EachMessagePayload) => {
    const event = JSON.parse(message.value!.toString());

    try {
      await processPaymentEvent(event);

      // Commit only after successful processing
      await consumer.commitOffsets([{
        topic,
        partition,
        offset: String(parseInt(message.offset) + 1),
      }]);
    } catch (err) {
      logger.error({ partition, offset: message.offset, err }, 'Message processing failed');
      // Do NOT commit — message will be redelivered on consumer restart
      // For non-retryable errors, send to DLT
      if (isNonRetryable(err)) {
        await sendToDeadLetterTopic(event, err as Error);
        // Commit to skip this message
        await consumer.commitOffsets([{ topic, partition, offset: String(parseInt(message.offset) + 1) }]);
      }
      // For retryable: let it re-process (don't commit)
    }

    // Call heartbeat for long-running processing to avoid rebalance
    await heartbeat();
  },
});
```

### Delivery Semantics

**At-least-once** (default): Producer retries on failure. Consumer may see duplicates on restart. Requires idempotent consumer.

**Idempotent producer** (exactly-once at producer level):
```typescript
const producer = kafka.producer({
  idempotent: true,               // Enables exactly-once production
  transactionalId: 'payment-tx', // Required for transactions
  maxInFlightRequests: 1,         // Required with idempotent=true
});
```

**Transactional exactly-once** (read-process-write atomically):
```typescript
await producer.transaction(async (tx) => {
  // Atomically: consume from input topic, produce to output topic
  await tx.send({ topic: 'processed-payments', messages: [result] });
  await tx.sendOffsets({
    consumerGroupId: 'payment-processors',
    topics: [{ topic: 'payments', partitions: [{ partition, offset: nextOffset }] }],
  });
  // Both commit atomically — neither happens without the other
});
```

### Dead Letter Topic (DLT)

```typescript
const DLT_SUFFIX = '.DLT';

async function sendToDeadLetterTopic(
  originalMessage: unknown,
  error: Error,
  sourceTopic: string
): Promise<void> {
  await producer.send({
    topic: `${sourceTopic}${DLT_SUFFIX}`,  // e.g., "payments.DLT"
    messages: [{
      key: (originalMessage as any).id,
      value: JSON.stringify(originalMessage),
      headers: {
        'x-original-topic': sourceTopic,
        'x-error-message': error.message,
        'x-error-type': error.constructor.name,
        'x-failed-at': new Date().toISOString(),
        'x-retry-count': String((originalMessage as any).retryCount ?? 0),
      },
    }],
  });
}

// DLT consumer — for manual inspection and replay
const dltConsumer = kafka.consumer({ groupId: 'dlt-processor' });
await dltConsumer.subscribe({ topic: 'payments.DLT' });
// Process: alert on-call, store in DB for dashboard, allow manual replay
```

### Schema Registry (Avro/Protobuf)

Prevents incompatible schema changes from breaking consumers:

```typescript
import { SchemaRegistry, SchemaType } from '@kafkajs/confluent-schema-registry';

const registry = new SchemaRegistry({ host: process.env.SCHEMA_REGISTRY_URL! });

// Register schema (on deploy)
const { id } = await registry.register({
  type: SchemaType.AVRO,
  schema: JSON.stringify({
    type: 'record',
    name: 'Payment',
    fields: [
      { name: 'id', type: 'string' },
      { name: 'amount', type: 'int' },
      { name: 'currency', type: 'string' },
      { name: 'status', type: { type: 'enum', name: 'Status', symbols: ['pending', 'succeeded', 'failed'] } },
      // Add new optional fields with defaults — backward compatible
      { name: 'metadata', type: ['null', { type: 'map', values: 'string' }], default: null },
    ],
  }),
}, { subject: 'payments-value' });

// Encode (producer)
const encodedValue = await registry.encode(id, paymentEvent);

// Decode (consumer)
const decodedValue = await registry.decode(message.value);
```

Schema evolution compatibility modes:
- `BACKWARD`: new schema can read old data (add optional fields, remove fields)
- `FORWARD`: old schema can read new data (remove optional fields, add fields with defaults)
- `FULL`: both directions

---

## RabbitMQ

### Exchange Types

```
direct   → Route by exact routing key match
           message(routing_key="payment.succeeded") → queue "payments-succeeded"

fanout   → Broadcast to all bound queues (ignores routing key)
           message → all queues bound to this exchange

topic    → Route by pattern matching (*, #)
           "payment.*"  matches "payment.succeeded", "payment.failed"
           "payment.#"  matches "payment.succeeded", "payment.card.declined"

headers  → Route by message header values (rarely used)
```

### Setup: Exchanges, Queues, Bindings

```typescript
import amqplib, { Channel, Connection } from 'amqplib';

async function setupRabbitMQ(): Promise<Channel> {
  const conn: Connection = await amqplib.connect(process.env.RABBITMQ_URL!);
  const channel: Channel = await conn.createChannel();

  // Dead letter exchange — receives failed messages
  await channel.assertExchange('payments.dlx', 'direct', { durable: true });
  await channel.assertQueue('payments.dlq', {
    durable: true,
    arguments: {
      'x-message-ttl': 7 * 24 * 60 * 60 * 1000, // Keep DLQ messages 7 days
    },
  });
  await channel.bindQueue('payments.dlq', 'payments.dlx', 'payments');

  // Main exchange
  await channel.assertExchange('payments', 'topic', { durable: true });

  // Main queue with DLX configured
  await channel.assertQueue('payment-processor', {
    durable: true,
    arguments: {
      'x-dead-letter-exchange': 'payments.dlx',
      'x-dead-letter-routing-key': 'payments',
      'x-message-ttl': 30 * 60 * 1000,  // Messages expire after 30min
      'x-max-length': 10000,             // Max queue depth
    },
  });

  // Bind queue to exchange with routing pattern
  await channel.bindQueue('payment-processor', 'payments', 'payment.#');

  // Fair dispatch — don't give more than 1 unack'd message per consumer
  await channel.prefetch(1);

  return channel;
}
```

### Publisher with Confirms

```typescript
async function publishWithConfirm(
  channel: Channel,
  exchange: string,
  routingKey: string,
  message: object
): Promise<void> {
  // Enable publisher confirms on this channel
  await channel.confirmSelect();

  const content = Buffer.from(JSON.stringify(message));
  const options = {
    contentType: 'application/json',
    persistent: true,            // Survive broker restart
    messageId: crypto.randomUUID(),
    timestamp: Math.floor(Date.now() / 1000),
    headers: { 'x-retry-count': 0 },
  };

  // waitForConfirms throws if message lost
  await new Promise<void>((resolve, reject) => {
    channel.publish(exchange, routingKey, content, options, (err) => {
      if (err) reject(err);
      else resolve();
    });
  });

  await channel.waitForConfirms();
}
```

### Consumer with Reconnection

```typescript
const RECONNECT_DELAY = 5000;

async function startConsumer(): Promise<void> {
  while (true) {
    try {
      const conn = await amqplib.connect(process.env.RABBITMQ_URL!);

      conn.on('error', (err) => {
        logger.error({ err }, 'RabbitMQ connection error');
      });
      conn.on('close', () => {
        logger.warn('RabbitMQ connection closed, reconnecting...');
      });

      const channel = await conn.createChannel();
      await channel.prefetch(10);  // Process up to 10 messages concurrently

      await channel.consume('payment-processor', async (msg) => {
        if (!msg) return;

        try {
          const event = JSON.parse(msg.content.toString());
          await processPaymentEvent(event);

          channel.ack(msg);  // Acknowledge success
        } catch (err) {
          const retryCount = (msg.properties.headers?.['x-retry-count'] ?? 0) + 1;
          const MAX_RETRIES = 5;

          if (retryCount >= MAX_RETRIES) {
            // Exhausted retries → send to DLQ via DLX
            logger.error({ err, retryCount }, 'Message failed, sending to DLQ');
            channel.nack(msg, false, false);  // nack, don't requeue → goes to DLX
          } else {
            // Requeue with incremented retry count and delay
            logger.warn({ retryCount }, 'Message failed, retrying');
            await publishWithDelay(channel, msg, retryCount);
            channel.ack(msg);  // Ack original, we published a new copy
          }
        }
      });

      // Wait for connection to close before reconnecting
      await new Promise((resolve) => conn.on('close', resolve));
    } catch (err) {
      logger.error({ err }, 'RabbitMQ consumer failed');
    }

    await new Promise(resolve => setTimeout(resolve, RECONNECT_DELAY));
  }
}
```

---

## Kafka vs RabbitMQ Decision Tree

```
Need > 10k messages/second?
  YES → Kafka (partitioned log, high throughput)
  NO  → Is message ordering per-key critical?
    YES → Kafka (partition by key)
    NO  → Is complex routing needed? (topic patterns, priority queues)
      YES → RabbitMQ (flexible exchange types)
      NO  → Is this an event log / audit trail / event sourcing?
        YES → Kafka (immutable log, replay from beginning, long retention)
        NO  → Is this a task queue (work distribution)?
          YES → RabbitMQ (fair dispatch, easy to add consumers)
          NO  → Do consumers need to process at their own pace independently?
            YES → Kafka (consumer groups, independent offsets)
            NO  → RabbitMQ (simpler ops, better UI, lower overhead)
```

**Choose Kafka for**:
- Event sourcing and CQRS (replay event history)
- Stream processing (joins, aggregations, windowing)
- Audit logs (compliance, debugging)
- High throughput data pipelines (logs, metrics, clicks)
- Multiple independent consumer groups on the same data

**Choose RabbitMQ for**:
- Task queues and job workers
- Complex routing (headers, priority, TTL per message)
- RPC-style messaging
- Lower throughput workloads (<10k/s)
- Teams preferring simpler operations

---

## Consumer Patterns

### Idempotent Consumer

```typescript
async function idempotentHandler<T>(
  messageId: string,
  handler: (data: T) => Promise<void>,
  data: T
): Promise<void> {
  // Try to claim this message ID
  const key = `processed:${messageId}`;
  const claimed = await redis.set(key, '1', { NX: true, EX: 86400 }); // 24h TTL

  if (!claimed) {
    logger.info({ messageId }, 'Duplicate message, skipping');
    return;
  }

  try {
    await handler(data);
  } catch (err) {
    // Release claim on failure so message can be retried
    await redis.del(key);
    throw err;
  }
}
```

### Outbox Pattern (Transactional Messaging)

Guarantees that a DB write and a message publish happen atomically:

```typescript
// Instead of publishing directly in a transaction, write to an outbox table
// A separate process reads the outbox and publishes

// In your transaction:
await db.transaction(async (tx) => {
  // 1. Update domain state
  await tx.query('UPDATE orders SET status = $1 WHERE id = $2', ['confirmed', orderId]);

  // 2. Write to outbox (same transaction — atomic)
  await tx.query(
    `INSERT INTO outbox_events (id, aggregate_type, aggregate_id, event_type, payload, created_at)
     VALUES ($1, $2, $3, $4, $5, NOW())`,
    [crypto.randomUUID(), 'order', orderId, 'order.confirmed', JSON.stringify({ orderId })]
  );
  // Transaction commits both together — no partial state
});

// Outbox relay process (runs on cron or using Debezium CDC)
async function relayOutboxEvents(): Promise<void> {
  const events = await db.query(
    `SELECT * FROM outbox_events WHERE published_at IS NULL ORDER BY created_at LIMIT 100`
  );

  for (const event of events.rows) {
    await kafkaProducer.send({
      topic: event.event_type.replace('.', '-'),
      messages: [{ key: event.aggregate_id, value: JSON.stringify(event.payload) }],
    });

    await db.query(
      'UPDATE outbox_events SET published_at = NOW() WHERE id = $1',
      [event.id]
    );
  }
}
```

### Saga: Orchestration vs Choreography

**Choreography** (event-driven, decentralized):
- Each service listens for events and emits its own events
- No central coordinator
- Good for: simple flows, loose coupling
- Weakness: hard to trace, rollbacks require compensating events

**Orchestration** (centralized coordinator):
- One saga orchestrator sends commands and handles responses
- Explicit state machine, easier to debug
- Good for: complex flows, strong consistency requirements

```typescript
// Orchestrated saga — Order fulfillment
class OrderFulfillmentSaga {
  async execute(orderId: string): Promise<void> {
    const saga = await this.createSagaInstance(orderId);

    try {
      // Step 1: Reserve inventory
      await this.inventoryService.reserve(orderId);
      await saga.markStep('inventory_reserved');

      // Step 2: Charge payment
      await this.paymentService.charge(orderId);
      await saga.markStep('payment_charged');

      // Step 3: Schedule shipping
      await this.shippingService.schedule(orderId);
      await saga.markStep('shipping_scheduled');

      await saga.complete();
    } catch (err) {
      // Compensate in reverse order
      await this.compensate(saga, err as Error);
    }
  }

  private async compensate(saga: SagaInstance, error: Error): Promise<void> {
    const completedSteps = saga.completedSteps;

    if (completedSteps.includes('payment_charged')) {
      await this.paymentService.refund(saga.orderId);
    }
    if (completedSteps.includes('inventory_reserved')) {
      await this.inventoryService.release(saga.orderId);
    }

    await saga.fail(error.message);
  }
}
```

---

## Monitoring

### Kafka Consumer Lag

Consumer lag = latest offset - committed offset. High lag = consumers falling behind.

```typescript
// Using kafkajs admin to check consumer group lag
const admin = kafka.admin();
await admin.connect();

async function getConsumerLag(groupId: string, topic: string): Promise<number> {
  const [offsets, groupOffsets] = await Promise.all([
    admin.fetchTopicOffsets(topic),
    admin.fetchOffsets({ groupId, topics: [topic] }),
  ]);

  let totalLag = 0;
  for (const partition of offsets) {
    const committed = groupOffsets
      .find(t => t.topic === topic)
      ?.partitions.find(p => p.partition === partition.partition);

    const latest = parseInt(partition.offset);
    const committed_offset = parseInt(committed?.offset ?? '0');
    totalLag += Math.max(0, latest - committed_offset);
  }

  return totalLag;
}

// Alert if lag > threshold
setInterval(async () => {
  const lag = await getConsumerLag('payment-processors', 'payments');
  metrics.gauge('kafka.consumer.lag', lag, { group: 'payment-processors', topic: 'payments' });

  if (lag > 10000) {
    alerting.fire('KafkaConsumerLagHigh', { lag, threshold: 10000 });
  }
}, 30000);
```

### Dead Letter Queue Depth Alerts

```typescript
// RabbitMQ: check DLQ depth via management API
async function getDLQDepth(queueName: string): Promise<number> {
  const response = await fetch(
    `${process.env.RABBITMQ_MGMT_URL}/api/queues/%2F/${queueName}`,
    {
      headers: {
        Authorization: `Basic ${Buffer.from(
          `${process.env.RABBITMQ_USER}:${process.env.RABBITMQ_PASS}`
        ).toString('base64')}`,
      },
    }
  );
  const data = await response.json();
  return data.messages ?? 0;
}

// Alert if DLQ has messages
setInterval(async () => {
  const depth = await getDLQDepth('payments.dlq');
  metrics.gauge('rabbitmq.dlq.depth', depth, { queue: 'payments.dlq' });

  if (depth > 0) {
    // Any DLQ message is an actionable alert
    alerting.fire('DLQMessagesFound', { depth, queue: 'payments.dlq' });
  }
}, 60000);
```

### Throughput and Error Rate Dashboard

Key metrics to track:

| Metric | Alert Threshold | Dimensions |
|--------|----------------|------------|
| `kafka.consumer.lag` | > 10,000 | consumer_group, topic |
| `kafka.producer.error_rate` | > 1% | topic |
| `rabbitmq.dlq.depth` | > 0 | queue |
| `rabbitmq.queue.depth` | > queue_capacity * 0.8 | queue |
| `message.processing.p99_latency` | > 5s | handler |
| `message.processing.error_rate` | > 5% | handler, event_type |
| `consumer.rebalance.count` | > 5/hour | consumer_group |

Rebalances disrupt processing — excessive rebalances indicate consumer crashes or deployment issues.
