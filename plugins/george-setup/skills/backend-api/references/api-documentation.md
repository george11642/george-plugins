# API Documentation Reference

## OpenAPI 3.1 Design

### Why OpenAPI 3.1
OpenAPI 3.1 aligns fully with JSON Schema 2020-12 (previously 3.0 had incompatibilities). Key gains:
- Types can be arrays: `type: [string, null]` replaces `nullable: true`
- Native `webhooks` object at the top level
- `$schema` keyword supported inside schemas
- Full JSON Schema vocabulary (`if/then/else`, `unevaluatedProperties`)

### YAML Structure

```yaml
openapi: 3.1.0
info:
  title: Payments API
  description: |
    Processes payments and manages subscriptions.
    See [changelog](#section/Changelog) for version history.
  version: 2.1.0
  contact:
    name: API Support
    email: api@example.com
  license:
    name: Apache 2.0
    url: https://www.apache.org/licenses/LICENSE-2.0

servers:
  - url: https://api.example.com/v2
    description: Production
  - url: https://staging-api.example.com/v2
    description: Staging
  - url: http://localhost:3000/v2
    description: Local development

tags:
  - name: payments
    description: Payment processing operations
  - name: subscriptions
    description: Subscription management

paths:
  /payments:
    post:
      tags: [payments]
      summary: Create a payment
      operationId: createPayment
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreatePaymentRequest'
            examples:
              card_payment:
                summary: Card payment
                value:
                  amount: 5000
                  currency: usd
                  source: tok_visa
      responses:
        '201':
          description: Payment created
          headers:
            Location:
              schema:
                type: string
              description: URL of the created payment
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Payment'
        '400':
          $ref: '#/components/responses/BadRequest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '429':
          $ref: '#/components/responses/RateLimited'
```

### Components: Schemas

Extract every reused shape into `components/schemas`. Rule: if a schema appears twice, it goes in components.

```yaml
components:
  schemas:
    # Base error shape (all errors extend this)
    Error:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
          description: Machine-readable error code
          example: VALIDATION_ERROR
        message:
          type: string
          description: Human-readable description
        details:
          type: array
          items:
            $ref: '#/components/schemas/ErrorDetail'

    ErrorDetail:
      type: object
      properties:
        field:
          type: string
        issue:
          type: string
        value:
          description: The rejected value (any type)

    # Pagination envelope
    PaginatedResponse:
      type: object
      required: [data, pagination]
      properties:
        data:
          type: array
          items: {}  # Override with allOf in specific responses
        pagination:
          $ref: '#/components/schemas/Pagination'

    Pagination:
      type: object
      required: [total, page, perPage, hasNext]
      properties:
        total:
          type: integer
        page:
          type: integer
        perPage:
          type: integer
        hasNext:
          type: boolean
        nextCursor:
          type: string
          nullable: true

    # Timestamps mixin — use allOf to compose
    Timestamps:
      type: object
      properties:
        createdAt:
          type: string
          format: date-time
        updatedAt:
          type: string
          format: date-time

    Payment:
      allOf:
        - $ref: '#/components/schemas/Timestamps'
        - type: object
          required: [id, amount, currency, status]
          properties:
            id:
              type: string
              format: uuid
            amount:
              type: integer
              description: Amount in smallest currency unit (cents)
              minimum: 1
            currency:
              type: string
              pattern: '^[a-z]{3}$'
              example: usd
            status:
              type: string
              enum: [pending, succeeded, failed, refunded]
```

### Discriminator for Polymorphic Responses

Use `discriminator` when a field determines the concrete type:

```yaml
components:
  schemas:
    PaymentMethod:
      oneOf:
        - $ref: '#/components/schemas/CardPayment'
        - $ref: '#/components/schemas/BankTransfer'
        - $ref: '#/components/schemas/WalletPayment'
      discriminator:
        propertyName: type
        mapping:
          card: '#/components/schemas/CardPayment'
          bank_transfer: '#/components/schemas/BankTransfer'
          wallet: '#/components/schemas/WalletPayment'

    CardPayment:
      type: object
      required: [type, last4, brand]
      properties:
        type:
          type: string
          enum: [card]
        last4:
          type: string
          pattern: '^\d{4}$'
        brand:
          type: string
          enum: [visa, mastercard, amex]
```

### Security Schemes

```yaml
components:
  securitySchemes:
    # JWT Bearer
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

    # API key in header
    apiKeyHeader:
      type: apiKey
      in: header
      name: X-API-Key

    # API key in query (less preferred — keys in URLs appear in logs)
    apiKeyQuery:
      type: apiKey
      in: query
      name: api_key

    # OAuth 2.0 with PKCE
    oauth2:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://auth.example.com/oauth/authorize
          tokenUrl: https://auth.example.com/oauth/token
          scopes:
            read:payments: Read payment data
            write:payments: Create and update payments
            admin: Full administrative access

# Apply globally (can be overridden per-operation)
security:
  - bearerAuth: []
```

### Reusable Responses

```yaml
components:
  responses:
    BadRequest:
      description: Validation error
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            code: VALIDATION_ERROR
            message: Request validation failed
            details:
              - field: amount
                issue: Must be a positive integer
    Unauthorized:
      description: Missing or invalid authentication
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
    Forbidden:
      description: Insufficient permissions
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
    RateLimited:
      description: Rate limit exceeded
      headers:
        Retry-After:
          schema:
            type: integer
          description: Seconds until the rate limit resets
        X-RateLimit-Limit:
          schema:
            type: integer
        X-RateLimit-Remaining:
          schema:
            type: integer
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
```

---

## Swagger Setup

### Express: swagger-jsdoc + swagger-ui-express

```bash
npm install swagger-jsdoc swagger-ui-express
npm install -D @types/swagger-jsdoc @types/swagger-ui-express
```

```typescript
// src/docs/swagger.ts
import swaggerJsdoc from 'swagger-jsdoc';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.1.0',
    info: {
      title: 'My API',
      version: '1.0.0',
      description: 'API documentation',
    },
    servers: [{ url: '/api/v1' }],
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: ['./src/routes/**/*.ts', './src/docs/schemas.yaml'],
};

export const swaggerSpec = swaggerJsdoc(options);
```

```typescript
// src/app.ts
import swaggerUi from 'swagger-ui-express';
import { swaggerSpec } from './docs/swagger';

// Mount only in non-production (or behind auth in production)
if (process.env.NODE_ENV !== 'production') {
  app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  app.get('/api/docs.json', (req, res) => res.json(swaggerSpec));
}
```

```typescript
// src/routes/payments.ts — JSDoc annotations
/**
 * @swagger
 * /payments:
 *   post:
 *     tags: [payments]
 *     summary: Create a payment
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreatePaymentRequest'
 *     responses:
 *       201:
 *         description: Payment created
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Payment'
 *       400:
 *         $ref: '#/components/responses/BadRequest'
 */
router.post('/', asyncHandler(createPayment));
```

### Fastify: @fastify/swagger + @fastify/swagger-ui

```bash
npm install @fastify/swagger @fastify/swagger-ui
```

```typescript
import fastifySwagger from '@fastify/swagger';
import fastifySwaggerUi from '@fastify/swagger-ui';

await fastify.register(fastifySwagger, {
  openapi: {
    openapi: '3.1.0',
    info: { title: 'My API', version: '1.0.0' },
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
  },
});

await fastify.register(fastifySwaggerUi, {
  routePrefix: '/docs',
  uiConfig: { docExpansion: 'list', deepLinking: true },
});

// Fastify routes carry schema inline — no JSDoc needed
fastify.post<{ Body: CreatePaymentRequest }>(
  '/payments',
  {
    schema: {
      tags: ['payments'],
      summary: 'Create a payment',
      body: { $ref: 'CreatePaymentRequest#' },
      response: {
        201: { $ref: 'Payment#' },
        400: { $ref: 'Error#' },
      },
    },
  },
  createPaymentHandler
);
```

Fastify advantage: schema is co-located with the route and used for both validation and documentation — single source of truth.

---

## OpenAPI-First Workflow

Design-first order of operations:

1. Write `openapi.yaml` (or split into multiple files with `$ref`)
2. Generate TypeScript types: `npx openapi-typescript openapi.yaml -o src/types/api.d.ts`
3. Generate mock server: `npx @stoplight/prism-cli mock openapi.yaml`
4. Frontend team develops against the mock server
5. Backend implements against the generated types
6. CI validates the spec and checks for breaking changes

### openapi-typescript

```bash
npm install -D openapi-typescript
```

```typescript
// Generated types from spec
import type { paths } from './types/api';

type CreatePaymentBody = paths['/payments']['post']['requestBody']['content']['application/json'];
type PaymentResponse = paths['/payments']['post']['responses']['201']['content']['application/json'];

// Runtime fetch with full type safety
const response = await fetch('/api/v1/payments', {
  method: 'POST',
  body: JSON.stringify(body satisfies CreatePaymentBody),
});
const payment: PaymentResponse = await response.json();
```

### oasdiff — Breaking Change Detection

```bash
npm install -g oasdiff
# or via Docker in CI

# Check for breaking changes between old and new spec
oasdiff breaking openapi-v1.yaml openapi-v2.yaml

# Exit code 1 if breaking changes found — use in CI
oasdiff breaking openapi-old.yaml openapi-new.yaml --fail-on-warns
```

Common breaking changes oasdiff catches:
- Removing or renaming a path or operation
- Removing a required request field
- Changing a response field type
- Adding a new required request field without a default
- Changing a path parameter name

### Prism Mock Server

```bash
npx @stoplight/prism-cli mock openapi.yaml --port 4010

# With dynamic data generation
npx @stoplight/prism-cli mock openapi.yaml --dynamic
```

---

## Changelog and Versioning

### Deprecation Headers

Signal deprecation without removing the endpoint:

```typescript
// Express middleware for deprecated routes
function deprecate(sunsetDate: string): RequestHandler {
  return (req, res, next) => {
    res.set('Deprecation', 'true');
    res.set('Sunset', sunsetDate);          // RFC 8594 date
    res.set('Link', '</v2/payments>; rel="successor-version"');
    next();
  };
}

router.post('/v1/payments', deprecate('2026-01-01'), createPaymentV1);
```

### Breaking vs Non-Breaking Changes

Non-breaking (safe to release):
- Adding optional request fields
- Adding new response fields
- Adding new endpoints
- Adding new enum values to responses (warn clients to handle unknown values)
- Relaxing validation constraints (e.g., raising max length)

Breaking (require version bump):
- Removing or renaming fields
- Changing field types
- Adding required request fields
- Tightening validation constraints
- Changing authentication scheme

### Migration Guide Pattern

When releasing a breaking version:
1. Keep v1 alive for at least 6 months after v2 launch
2. Add `Deprecation: true` + `Sunset: <date>` headers to v1
3. Publish a migration guide in docs
4. Email registered developers 3 months before sunset
5. Return 410 Gone after sunset (not 404)

---

## SDK Generation

### openapi-generator

```bash
# TypeScript SDK
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./sdk/typescript \
  --additional-properties=supportsES6=true,npmName=my-api-sdk,npmVersion=1.0.0

# Python SDK
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o ./sdk/python \
  --additional-properties=packageName=my_api_sdk

# Go SDK
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g go \
  -o ./sdk/go \
  --additional-properties=packageName=myapi
```

Maintaining generated SDKs:
- Keep generation scripts in `Makefile` or `package.json` scripts
- Commit generated SDKs (consumers don't need generator tooling)
- Bump SDK minor version on non-breaking spec changes, major on breaking
- Run generator in CI to detect spec/SDK drift

---

## Documentation Checklist

- [ ] OpenAPI spec committed to repo and published at `/api/docs`
- [ ] All endpoints have `operationId`, `summary`, and at least one `tag`
- [ ] Every request body has a schema with required fields marked
- [ ] Every response (including 4xx/5xx) has a schema
- [ ] All endpoints have at least one `example` per media type
- [ ] Error codes documented (machine-readable `code` field values listed)
- [ ] Rate limits documented (per-plan limits in description or `x-ratelimit` extension)
- [ ] Authentication documented in `securitySchemes` with usage instructions
- [ ] Breaking change detection runs in CI (`oasdiff` or equivalent)
- [ ] Deprecation headers set on any endpoints scheduled for removal
- [ ] SDK generation reproducible from Makefile/script
- [ ] Changelog maintained for every version with breaking/non-breaking labels
