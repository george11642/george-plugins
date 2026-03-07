# Serverless API Routes

File-based routing for Expo Router with EAS Hosting (Cloudflare Workers). Also applies to any Web Standard Request/Response environment (Next.js App Router, Hono, etc.).

---

## When to Use Serverless API Routes

**Use when you need:**
- Server-side secrets (API keys, DB credentials) that must never reach the client
- Direct database queries or third-party API proxies
- Server-side validation, webhook receivers, or heavy computation
- Rate limiting at the edge

**Avoid when:**
- Data is already public — call the external API directly from the client
- Real-time bidirectional updates — use WebSockets or Supabase Realtime
- Simple CRUD — managed backends (Supabase, Firebase, Convex) are faster to ship
- File uploads — use direct-to-storage presigned URLs (S3, Cloudflare R2)

---

## File Conventions (Expo Router)

API routes live in the `app/` directory with a `+api.ts` suffix:

```
app/
  api/
    hello+api.ts            → GET /api/hello
    users+api.ts            → GET /api/users, POST /api/users
    users/[id]+api.ts       → GET /api/users/:id, PATCH /api/users/:id
    webhooks/stripe+api.ts  → POST /api/webhooks/stripe
```

---

## Basic Structure

Export named functions for each HTTP method. Unhandled methods return `405 Method Not Allowed` automatically.

```typescript
// app/api/users+api.ts
import { createClient } from '@libsql/client/web';

const db = createClient({
  url:       process.env.TURSO_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

export async function GET(request: Request) {
  const url   = new URL(request.url);
  const page  = Number(url.searchParams.get('page')  ?? 1);
  const limit = Number(url.searchParams.get('limit') ?? 20);
  const offset = (page - 1) * limit;

  const result = await db.execute({
    sql:  'SELECT id, name, email FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?',
    args: [limit, offset],
  });

  return Response.json({ data: result.rows, page, limit });
}

export async function POST(request: Request) {
  const body = await request.json() as { name: string; email: string };

  if (!body.name || !body.email) {
    return Response.json({ error: 'name and email are required' }, { status: 400 });
  }

  const result = await db.execute({
    sql:  'INSERT INTO users (name, email) VALUES (?, ?) RETURNING id, name, email',
    args: [body.name.trim(), body.email.toLowerCase()],
  });

  return Response.json({ data: result.rows[0] }, { status: 201 });
}
```

---

## Dynamic Routes

The second argument receives route params as an object:

```typescript
// app/api/users/[id]+api.ts
export async function GET(request: Request, { id }: { id: string }) {
  const result = await db.execute({
    sql:  'SELECT id, name, email FROM users WHERE id = ?',
    args: [id],
  });

  if (result.rows.length === 0) {
    return Response.json({ error: 'User not found' }, { status: 404 });
  }

  return Response.json({ data: result.rows[0] });
}

export async function PATCH(request: Request, { id }: { id: string }) {
  const updates = await request.json() as Record<string, string>;

  const allowed = ['name', 'email'] as const;
  const fields  = Object.keys(updates).filter(k => allowed.includes(k as typeof allowed[number]));

  if (fields.length === 0) {
    return Response.json({ error: 'No valid fields to update' }, { status: 400 });
  }

  const setClause = fields.map((f, i) => `${f} = ?`).join(', ');
  const values    = fields.map(f => updates[f]);

  await db.execute({
    sql:  `UPDATE users SET ${setClause} WHERE id = ?`,
    args: [...values, id],
  });

  return Response.json({ success: true });
}

export async function DELETE(_request: Request, { id }: { id: string }) {
  await db.execute({ sql: 'DELETE FROM users WHERE id = ?', args: [id] });
  return new Response(null, { status: 204 });
}
```

---

## Authentication Pattern

Throw a `Response` to short-circuit — Expo Router will forward it as-is:

```typescript
// utils/auth.ts
export interface AuthUser {
  userId: string;
  email:  string;
  roles:  string[];
}

export async function requireAuth(request: Request): Promise<AuthUser> {
  const token = request.headers.get('Authorization')?.replace('Bearer ', '');

  if (!token) {
    throw new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status:  401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Verify JWT using Web Crypto (no Node.js crypto module available)
  try {
    const payload = await verifyJWT(token, process.env.JWT_SECRET!);
    return payload as AuthUser;
  } catch {
    throw new Response(JSON.stringify({ error: 'Invalid or expired token' }), {
      status:  401,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

// JWT verification with Web Crypto API
async function verifyJWT(token: string, secret: string): Promise<unknown> {
  const [headerB64, payloadB64, sigB64] = token.split('.');

  const encoder   = new TextEncoder();
  const keyData   = encoder.encode(secret);
  const cryptoKey = await crypto.subtle.importKey(
    'raw', keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false, ['verify'],
  );

  const data      = encoder.encode(`${headerB64}.${payloadB64}`);
  const sigBuffer = Uint8Array.from(atob(sigB64.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));

  const valid = await crypto.subtle.verify('HMAC', cryptoKey, sigBuffer, data);
  if (!valid) throw new Error('Invalid signature');

  const payload = JSON.parse(atob(payloadB64));
  if (payload.exp && payload.exp < Date.now() / 1000) throw new Error('Token expired');
  return payload;
}
```

```typescript
// app/api/profile+api.ts
import { requireAuth } from '../../utils/auth';

export async function GET(request: Request) {
  const { userId } = await requireAuth(request);

  const result = await db.execute({
    sql:  'SELECT id, name, email FROM users WHERE id = ?',
    args: [userId],
  });

  return Response.json({ data: result.rows[0] });
}
```

---

## CORS Headers

```typescript
// utils/cors.ts
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS?.split(',') ?? [];

export function corsHeaders(request: Request): HeadersInit {
  const origin = request.headers.get('origin') ?? '';
  const allowed = ALLOWED_ORIGINS.includes(origin) ? origin : '';
  return {
    'Access-Control-Allow-Origin':  allowed,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age':       '86400',
  };
}

// Every route that needs CORS must export OPTIONS
export function OPTIONS(request: Request) {
  return new Response(null, { status: 204, headers: corsHeaders(request) });
}
```

```typescript
// app/api/data+api.ts
import { corsHeaders, OPTIONS } from '../../utils/cors';
export { OPTIONS };

export async function GET(request: Request) {
  const data = { message: 'Hello' };
  return Response.json(data, { headers: corsHeaders(request) });
}
```

---

## Environment Variables

```typescript
// Local: .env (never commit)
// OPENAI_API_KEY=sk-...
// TURSO_URL=libsql://...
// TURSO_AUTH_TOKEN=eyJ...

// EAS Hosting: eas env:create
// eas env:create --name OPENAI_API_KEY --value "sk-xxx" --environment production --visibility secret

// Access in routes:
process.env.OPENAI_API_KEY   // available server-side only — never reaches client
```

---

## Serverless Constraints (Cloudflare Workers / EAS Hosting)

| Capability          | Status                          | Alternative                         |
|---------------------|---------------------------------|-------------------------------------|
| `fs` module         | Not available                   | Cloud storage (R2, S3)              |
| Native Node modules | Not available                   | Web-compatible packages             |
| Execution time      | 30s CPU limit                   | Offload to queue/background job     |
| Persistent memory   | Not available (stateless)       | Redis, KV store, database           |
| WebSockets          | Requires Durable Objects        | Supabase Realtime, Pusher           |
| `crypto`            | Use `crypto.subtle` (Web Crypto)| —                                   |
| `fetch`             | Available natively              | —                                   |

### Use Web APIs Instead of Node APIs

```typescript
// Hash with Web Crypto (replaces Node's crypto.createHash)
async function sha256(data: string): Promise<string> {
  const buf    = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
}

// Generate random ID (replaces crypto.randomUUID or uuid package)
const id = crypto.randomUUID();

// Timing-safe comparison (replaces crypto.timingSafeEqual)
async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const enc   = new TextEncoder();
  const keyA  = await crypto.subtle.importKey('raw', enc.encode(a), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig   = await crypto.subtle.sign('HMAC', keyA, enc.encode(b));
  return sig.byteLength > 0 && a.length === b.length; // simplified — use a real impl in production
}
```

---

## Database Options for Serverless

| Database      | Type               | SDK                              | Notes                              |
|---------------|--------------------|----------------------------------|------------------------------------|
| Turso         | Distributed SQLite | `@libsql/client/web`             | HTTP-based, works in Workers       |
| Cloudflare D1 | SQLite at edge     | `@cloudflare/workers-types`      | Native Workers binding             |
| PlanetScale   | Serverless MySQL   | `@planetscale/database`          | HTTP-based driver                  |
| Neon          | Serverless Postgres| `@neondatabase/serverless`       | WebSocket + HTTP driver            |
| Supabase      | Postgres           | `@supabase/supabase-js`          | REST + Realtime                    |

### Turso Example

```typescript
// app/api/posts+api.ts
import { createClient } from '@libsql/client/web';

const db = createClient({
  url:       process.env.TURSO_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

export async function GET(request: Request) {
  const url    = new URL(request.url);
  const cursor = url.searchParams.get('cursor'); // cursor-based pagination

  const result = await db.execute({
    sql:  cursor
      ? 'SELECT * FROM posts WHERE id < ? ORDER BY id DESC LIMIT 20'
      : 'SELECT * FROM posts ORDER BY id DESC LIMIT 20',
    args: cursor ? [cursor] : [],
  });

  const rows       = result.rows;
  const nextCursor = rows.length === 20 ? String(rows[rows.length - 1].id) : null;

  return Response.json({ data: rows, nextCursor });
}
```

### Neon (Serverless Postgres) Example

```typescript
import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL!);

export async function GET() {
  const users = await sql`SELECT id, name, email FROM users WHERE active = true LIMIT 50`;
  return Response.json({ data: users });
}
```

---

## Webhook Receiver

```typescript
// app/api/webhooks/stripe+api.ts
export async function POST(request: Request) {
  const signature = request.headers.get('stripe-signature');
  const body      = await request.text(); // raw body for signature verification

  if (!signature) {
    return Response.json({ error: 'Missing stripe-signature' }, { status: 400 });
  }

  // Verify webhook signature using Web Crypto
  const isValid = await verifyStripeSignature(body, signature, process.env.STRIPE_WEBHOOK_SECRET!);
  if (!isValid) {
    return Response.json({ error: 'Invalid signature' }, { status: 400 });
  }

  const event = JSON.parse(body) as { type: string; data: { object: Record<string, unknown> } };

  switch (event.type) {
    case 'payment_intent.succeeded':
      await handlePaymentSuccess(event.data.object);
      break;
    case 'customer.subscription.deleted':
      await handleSubscriptionCancelled(event.data.object);
      break;
    default:
      // Unknown event type — acknowledge but don't process
  }

  return Response.json({ received: true });
}

async function verifyStripeSignature(payload: string, header: string, secret: string): Promise<boolean> {
  const parts     = header.split(',').reduce((acc, part) => {
    const [k, v] = part.split('=');
    acc[k] = v;
    return acc;
  }, {} as Record<string, string>);

  const timestamp  = parts['t'];
  const signature  = parts['v1'];
  const signedPayload = `${timestamp}.${payload}`;

  const encoder = new TextEncoder();
  const key     = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig     = await crypto.subtle.sign('HMAC', key, encoder.encode(signedPayload));
  const computed = Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('');

  return computed === signature;
}
```

---

## External API Proxy (Hide Secrets)

```typescript
// app/api/ai/chat+api.ts
export async function POST(request: Request) {
  const { prompt, model = 'gpt-4o' } = await request.json() as { prompt: string; model?: string };

  if (!prompt?.trim()) {
    return Response.json({ error: 'prompt is required' }, { status: 400 });
  }

  const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
    method:  'POST',
    headers: {
      'Content-Type':  'application/json',
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model,
      messages:    [{ role: 'user', content: prompt }],
      max_tokens:  1000,
      temperature: 0.7,
    }),
  });

  if (!upstream.ok) {
    const err = await upstream.json() as { error?: { message: string } };
    return Response.json({ error: err.error?.message ?? 'Upstream error' }, { status: 502 });
  }

  return Response.json(await upstream.json());
}
```

---

## Deployment

```bash
# Test locally
npx expo serve

# Deploy to EAS Hosting (Cloudflare Workers)
eas deploy

# Set production secrets
eas env:create --name DATABASE_URL --value "..." --environment production --visibility secret

# Custom domain — configure in eas.json or Expo dashboard
```

```json
// eas.json
{
  "deploy": {
    "production": {
      "url": "https://api.myapp.com"
    }
  }
}
```

---

## Rules

- Never expose API keys or secrets in client code
- Always validate and sanitize user input before database writes
- Use proper HTTP status codes (200, 201, 204, 400, 401, 403, 404, 409, 500)
- Use `crypto.subtle` (Web Crypto) — never `require('crypto')`
- Use `@libsql/client/web` not `@libsql/client` — the non-web build uses Node.js fs
- Raw body for webhook verification — call `request.text()` before `request.json()`
- Export `OPTIONS` on every route that needs CORS
- Never use `while(true)` or blocking loops — Cloudflare Workers are CPU-capped
