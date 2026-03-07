# Serverless Reference

## AWS Lambda

### Handler Structure

```python
# Python handler
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    event: dict with trigger-specific payload
    context: Lambda context object (function name, request ID, remaining time)
    """
    logger.info("Event: %s", json.dumps(event))

    try:
        # Business logic
        body = json.loads(event.get("body", "{}"))
        result = process(body)

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(result)
        }
    except ValueError as e:
        return {"statusCode": 400, "body": json.dumps({"error": str(e)})}
    except Exception as e:
        logger.exception("Unhandled error")
        return {"statusCode": 500, "body": json.dumps({"error": "Internal error"})}
```

```javascript
// Node.js handler
export const handler = async (event, context) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  try {
    const body = JSON.parse(event.body || '{}');
    const result = await process(body);

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(result),
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: error.statusCode ?? 500,
      body: JSON.stringify({ error: error.message }),
    };
  }
};
```

### Runtimes and Configuration

| Runtime | Identifier | Notes |
|---------|-----------|-------|
| Node.js 20 | `nodejs20.x` | Recommended for JS/TS |
| Python 3.12 | `python3.12` | Recommended for Python |
| Java 21 | `java21` | Slowest cold start |
| Go 1.x | `provided.al2023` | Custom runtime, fast cold start |
| Container image | `Image` | Up to 10GB, any language |

**Memory**: 128MB–10GB. CPU scales linearly with memory (1 vCPU at 1769MB). More memory = faster execution = potentially lower cost if duration drops proportionally.

**Timeout**: max 15 minutes. Default 3 seconds (too low — always set explicitly).

**Concurrency**: default 1000 concurrent executions per region (soft limit, can increase). Reserved concurrency guarantees capacity but also caps it.

### Cold Start Mitigation

Cold start = container initialization + runtime init + function init. Happens on first invocation or scale-out.

```hcl
# Terraform: Provisioned Concurrency
resource "aws_lambda_function" "api" {
  function_name = "myapp-api"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = 512
  timeout       = 30

  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")
  role             = aws_iam_role.lambda.arn
}

resource "aws_lambda_provisioned_concurrency_config" "api" {
  function_name                  = aws_lambda_function.api.function_name
  qualifier                      = aws_lambda_alias.live.name
  provisioned_concurrent_executions = 5  # Keep 5 warm instances
}
```

**Strategies to minimize cold starts**:
1. **Provisioned concurrency**: keeps N instances warm. Costs ~65% of on-demand price for those instances
2. **arm64 architecture**: Graviton2 is 20-34% faster and 20% cheaper than x86
3. **Move initialization outside the handler**: DB connections, SDK clients, config loading at module load time (outside handler function) — reused across warm invocations
4. **Keep package size small**: Lambda downloads your package on cold start. Smaller = faster
5. **Use Node.js or Python**: Java and .NET have the worst cold starts (~1-3s vs ~100ms)

```javascript
// GOOD: initialize outside handler (reused across invocations)
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
const dynamo = new DynamoDBClient({ region: process.env.AWS_REGION });

export const handler = async (event) => {
  // dynamo client already initialized
  await dynamo.send(...);
};
```

### Event Sources

**API Gateway / Function URL** — HTTP trigger

```hcl
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"  # Or "AWS_IAM" for private APIs

  cors {
    allow_origins = ["https://myapp.com"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}
```

**S3** — triggered on object creation/deletion

```hcl
resource "aws_s3_bucket_notification" "trigger" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".jpg"
  }
}
```

**SQS** — process queue messages in batches

```hcl
resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 10
  # Partial batch failure: report failed message IDs so only they go back to queue
  function_response_types = ["ReportBatchItemFailures"]
}
```

```javascript
// SQS handler with partial batch failure reporting
export const handler = async (event) => {
  const failures = [];

  for (const record of event.Records) {
    try {
      await processMessage(JSON.parse(record.body));
    } catch (error) {
      console.error(`Failed to process ${record.messageId}:`, error);
      failures.push({ itemIdentifier: record.messageId });
    }
  }

  return { batchItemFailures: failures };
};
```

**SNS** — fan-out notifications

```hcl
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.processor.arn
}
```

**DynamoDB Streams** — react to table changes

```hcl
resource "aws_lambda_event_source_mapping" "dynamo" {
  event_source_arn  = aws_dynamodb_table.orders.stream_arn
  function_name     = aws_lambda_function.stream_processor.arn
  starting_position = "LATEST"
  batch_size        = 100
}
```

**EventBridge** — scheduled and event-driven triggers

```hcl
# Scheduled (cron)
resource "aws_cloudwatch_event_rule" "daily" {
  name                = "daily-cleanup"
  schedule_expression = "cron(0 6 * * ? *)"  # 6am UTC daily
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.cleanup.arn
}
```

### Lambda Layers

Layers share code/dependencies across multiple functions. Max 5 layers per function, 250MB total unzipped.

```bash
# Create a layer with shared dependencies
mkdir -p layer/nodejs
cd layer/nodejs && npm install axios lodash
cd ../..
zip -r layer.zip layer/

aws lambda publish-layer-version \
  --layer-name shared-deps \
  --zip-file fileb://layer.zip \
  --compatible-runtimes nodejs20.x
```

```hcl
resource "aws_lambda_function" "api" {
  layers = [
    aws_lambda_layer_version.shared.arn,
    "arn:aws:lambda:us-east-1:580247275435:layer:LambdaInsightsExtension:38"  # AWS-managed
  ]
}
```

### VPC Integration

By default Lambda runs outside your VPC. Enable VPC to reach private RDS, ElastiCache, or internal services.

```hcl
resource "aws_lambda_function" "api" {
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}
```

Note: VPC Lambda requires ENI allocation, which adds 100-500ms cold start overhead (largely mitigated by hyperplane ENIs in recent Lambda versions). Ensure subnets have enough available IPs.

---

## GCP Cloud Functions

### 1st Gen vs 2nd Gen

| Feature | 1st Gen | 2nd Gen |
|---------|---------|---------|
| Max timeout | 9 minutes | 60 minutes |
| Max memory | 8GB | 32GB |
| Max concurrency | 1 per instance | Up to 1000 per instance |
| Min instances | Not supported | Supported |
| Based on | Cloud Functions runtime | Cloud Run |
| VPC | Cloud VPC connector | Direct VPC egress |

2nd gen is preferred for new deployments. Uses same infrastructure as Cloud Run.

### HTTP Function

```python
# main.py
import functions_framework
import json

@functions_framework.http
def handler(request):
    """HTTP trigger"""
    if request.method != 'POST':
        return ('Method Not Allowed', 405)

    data = request.get_json(silent=True)
    if not data:
        return ('Bad Request', 400)

    result = process(data)
    return json.dumps(result), 200, {'Content-Type': 'application/json'}
```

```bash
# Deploy 2nd gen HTTP function
gcloud functions deploy myfunction \
  --gen2 \
  --runtime python312 \
  --region us-central1 \
  --source . \
  --entry-point handler \
  --trigger-http \
  --allow-unauthenticated \
  --memory 512Mi \
  --timeout 60s \
  --min-instances 1
```

### Event Sources

**Cloud Storage** — object finalize, delete, archive, metadata update

```bash
gcloud functions deploy image-processor \
  --gen2 \
  --runtime nodejs20 \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=my-uploads-bucket"
```

**Pub/Sub** — subscribe to a topic

```bash
gcloud functions deploy message-processor \
  --gen2 \
  --runtime python312 \
  --trigger-topic my-topic
```

```python
import base64
import functions_framework

@functions_framework.cloud_event
def handler(cloud_event):
    data = base64.b64decode(cloud_event.data["message"]["data"]).decode()
    print(f"Message: {data}")
```

---

## Azure Functions

### Triggers and Bindings

Azure Functions use declarative input/output bindings — no SDK calls needed for common operations.

```javascript
// HTTP trigger (Node.js v4 programming model)
import { app } from '@azure/functions';

app.http('myFunction', {
  methods: ['GET', 'POST'],
  authLevel: 'anonymous',
  handler: async (request, context) => {
    const body = await request.json();
    context.log('Processing:', body);

    return {
      status: 200,
      jsonBody: { result: 'ok' }
    };
  }
});
```

```python
# Timer trigger (Python)
import azure.functions as func
import logging
from datetime import datetime

app = func.FunctionApp()

@app.timer_trigger(schedule="0 */5 * * * *", arg_name="timer")
def cleanup(timer: func.TimerRequest) -> None:
    logging.info("Running cleanup at %s", datetime.now())
    # Runs every 5 minutes
```

**Blob trigger** — react to new files in Azure Storage

```python
@app.blob_trigger(arg_name="blob", path="uploads/{name}", connection="AzureWebJobsStorage")
@app.blob_output(arg_name="output", path="processed/{name}", connection="AzureWebJobsStorage")
def process_upload(blob: func.InputStream, output: func.Out[bytes]) -> None:
    logging.info("Processing: %s (%d bytes)", blob.name, blob.length)
    processed = transform(blob.read())
    output.set(processed)
```

**Queue trigger** — process Azure Storage Queue messages

```python
@app.queue_trigger(arg_name="msg", queue_name="jobs", connection="AzureWebJobsStorage")
def process_job(msg: func.QueueMessage) -> None:
    payload = msg.get_json()
    logging.info("Processing job: %s", payload)
```

### Durable Functions (Fan-Out / Fan-In)

Durable Functions enable stateful orchestration patterns. The orchestrator function is replayed from history — all activity calls must be deterministic.

```python
import azure.functions as func
import azure.durable_functions as df

app = df.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Orchestrator: fan-out parallel activities, then aggregate
@app.orchestration_trigger(context_name="context")
def orchestrator(context: df.DurableOrchestrationContext):
    # Fan-out: kick off parallel tasks
    items = yield context.call_activity("get_items", None)

    parallel_tasks = [context.call_activity("process_item", item) for item in items]
    results = yield context.task_all(parallel_tasks)  # Wait for all

    # Fan-in: aggregate results
    summary = yield context.call_activity("summarize", results)
    return summary

# Activity: actual work (runs independently, retried on failure)
@app.activity_trigger(input_name="item")
def process_item(item: dict) -> dict:
    return {"id": item["id"], "result": expensive_operation(item)}

# HTTP starter: trigger the orchestration
@app.route(route="start")
@app.durable_client_input(client_name="client")
async def http_start(req: func.HttpRequest, client: df.DurableOrchestrationClient):
    instance_id = await client.start_new("orchestrator")
    return client.create_check_status_response(req, instance_id)
```

---

## Common Serverless Patterns

### Local Testing

**AWS SAM** (Serverless Application Model):

```bash
# Install SAM CLI
pip install aws-sam-cli

# Invoke function locally
sam local invoke MyFunction --event events/s3.json

# Start local HTTP API
sam local start-api --port 3000

# Generate test events
sam local generate-event s3 put --bucket my-bucket --key uploads/test.jpg
```

**GCP Functions Framework**:

```bash
# Install
pip install functions-framework

# Run locally
functions-framework --target handler --port 8080 --debug

# Test
curl -X POST http://localhost:8080 -H "Content-Type: application/json" -d '{"key": "value"}'
```

**Azure Functions Core Tools**:

```bash
# Install
npm install -g azure-functions-core-tools@4

# Run locally
func start

# Create new function
func new --name MyFunction --template "HTTP trigger"
```

### Structured Logging

Always log structured JSON in Lambda/Cloud Functions. Log aggregators (CloudWatch, Cloud Logging) can filter and query on JSON fields.

```python
import json
import logging

logger = logging.getLogger()

def handler(event, context):
    logger.info(json.dumps({
        "event": "request_received",
        "request_id": context.aws_request_id,
        "user_id": event.get("userId"),
        "action": "process_order"
    }))
```

```javascript
// Structured logging for Lambda (use powertools for production)
import { Logger } from '@aws-lambda-powertools/logger';
const logger = new Logger({ serviceName: 'orders-service' });

export const handler = async (event) => {
  logger.info('Processing order', { orderId: event.orderId, userId: event.userId });
};
```

### Error Handling and Dead Letter Queues

Async invocations (S3, SNS, EventBridge) retry twice on failure, then send to DLQ.

```hcl
resource "aws_lambda_function" "processor" {
  # ...
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }
}

resource "aws_sqs_queue" "dlq" {
  name                      = "processor-dlq"
  message_retention_seconds = 1209600  # 14 days
}
```

For SQS event source mappings, use `ReportBatchItemFailures` (see event source example above) to avoid reprocessing successful messages when one fails.

### Cost Optimization

| Technique | Saving | How |
|-----------|--------|-----|
| arm64 architecture | 20% compute + 20% cost | `aws lambda update-function-configuration --architectures arm64` |
| Memory tuning | Variable | Use AWS Lambda Power Tuning tool to find optimal memory |
| Provisioned concurrency only for peak hours | Reduce idle cost | Schedule via Application Auto Scaling |
| Batch SQS processing | Fewer invocations | Increase `batch_size` on SQS trigger |
| Keep dependencies small | Faster cold starts | Use tree-shaking, avoid bundling unused SDK clients |
| Reuse connections | Reduce per-invocation overhead | Initialize DB/HTTP clients outside handler |

**Memory tuning**: Lambda bills for duration × memory. At 128MB a function might take 800ms. At 512MB it takes 200ms. Cost = (512/128) × (200/800) = 0.5× the cost at 4× the memory. Always benchmark.

### Event-Driven Architecture Patterns

**Fan-out via SNS**: one event triggers multiple independent processors

```
S3 Upload → Lambda (validator) → SNS topic
                                    ├── Lambda (thumbnail generator)
                                    ├── Lambda (metadata extractor)
                                    └── Lambda (virus scanner)
```

**Queue-based load leveling**: decouple producers from consumers

```
API Gateway → Lambda (enqueue) → SQS → Lambda (processor, limited concurrency)
```

Limits Lambda concurrency on the processor to prevent overwhelming downstream services (DB, external APIs).

**Saga pattern** for distributed transactions: use Step Functions (AWS) or Durable Functions (Azure) to coordinate multi-step workflows with compensating transactions on failure.

```
Order Saga:
  1. Reserve inventory
  2. Charge payment
  3. Ship order
  (If step 3 fails → refund payment → release inventory)
```

**Choreography vs Orchestration**:
- Choreography: services emit events, others react. Loosely coupled, harder to trace
- Orchestration: central orchestrator (Step Functions, Durable Functions) directs each step. Easier to monitor, single point of failure

### Serverless Anti-Patterns

1. **Long-running synchronous tasks** — Lambda max timeout is 15 min. Move to SQS + async Lambda or Step Functions
2. **Shared mutable state between invocations** — Lambda may have multiple instances; don't rely on in-memory state persisting. Use Redis/DynamoDB
3. **Synchronous fan-out** — invoking 100 Lambdas synchronously from one Lambda creates tight coupling. Use SNS/SQS for fan-out
4. **No DLQ for async triggers** — without a DLQ, failed events are silently dropped after retries
5. **Ignoring cold starts for latency-sensitive APIs** — use provisioned concurrency or warm-up pings for p99 latency SLAs
6. **VPC Lambda without enough IPs** — Lambda can exhaust subnet IPs at scale. Use dedicated subnets with /24 or larger CIDR blocks
7. **Synchronous DB calls in high-concurrency functions** — each invocation holds a DB connection. Use RDS Proxy to pool connections
