---
name: auth-clerk
description: "Use when setting up Clerk authentication, configuring auth middleware, protecting routes, or handling Clerk webhooks. Triggers on Clerk, Clerk auth, ClerkProvider, auth middleware, protected routes, Clerk webhook, Svix, sign-in, sign-up, Clerk token, getToken, Clerk secret key, publishable key, Clerk setup, CAPTCHA signup, Clerk Next.js, Clerk React, Clerk Expo, user.created event, session management, Clerk identity."
allowed-tools: WebFetch
---

# Clerk Authentication

Patterns for adding and managing Clerk auth across frameworks. Use `clerk-setup` skill for initial project setup; this skill covers ongoing patterns and gotchas.

## Framework Detection

Check `package.json` to identify framework, then fetch the matching quickstart:

| Dependency | Framework | Quickstart URL |
|------------|-----------|----------------|
| `next` | Next.js | `clerk.com/docs/nextjs/getting-started/quickstart` |
| `@remix-run/react` | Remix | `clerk.com/docs/remix/getting-started/quickstart` |
| `astro` | Astro | `clerk.com/docs/astro/getting-started/quickstart` |
| `react` (no framework) | React SPA | `clerk.com/docs/react/getting-started/quickstart` |
| `expo` | Expo | `clerk.com/docs/expo/getting-started/quickstart` |
| `express` | Express | `clerk.com/docs/expressjs/getting-started/quickstart` |
| `vue` | Vue | `clerk.com/docs/vue/getting-started/quickstart` |

## Package Names

| Framework | Package |
|-----------|---------|
| Next.js | `@clerk/nextjs` |
| React | `@clerk/react` |
| Expo | `@clerk/expo` |
| React Router | `@clerk/react-router` |
| TanStack Start | `@clerk/tanstack-react-start` |

## Key Patterns

### ClerkProvider Placement (Next.js)
Must be inside `<body>`, NOT wrapping `<html>`:
```tsx
export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <ClerkProvider>{children}</ClerkProvider>
      </body>
    </html>
  )
}
```

### Dynamic Rendering (Next.js)
For server-rendered auth data:
```tsx
<ClerkProvider dynamic>{children}</ClerkProvider>
```

### Identity Check (Backend)
When verifying identity from Clerk tokens:
```ts
const identity = await ctx.auth.getUserIdentity();
// Compare identity.subject === clerkUserId
// Do NOT use tokenIdentifier.includes() -- fragile and error-prone
```

### Calling Mutations from API Routes (Next.js)
Pass the Clerk token explicitly:
```ts
const { getToken } = await auth();
const token = await getToken({ template: "convex" }) ?? undefined;
await fetchMutation(api.some.mutation, args, { token });
```

### Middleware Matcher
Include API routes and exclude static files:
```ts
export const config = {
  matcher: ['/((?!.*\\..*|_next).*)', '/']
};
```
To keep landing page public:
```ts
matcher: ['/((?!.*\\..*|_next|^/$).*)', '/api/(.*)']
```

## Environment Variables

```
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
```
- Publishable key: `pk_test_` (dev) or `pk_live_` (prod) -- safe for client
- Secret key: `sk_test_` or `sk_live_` -- server only, NEVER expose to client

## shadcn Theme

If project uses shadcn/ui (has `components.json`):
```tsx
import { shadcn } from '@clerk/ui/themes'
<ClerkProvider appearance={{ theme: shadcn }}>{children}</ClerkProvider>
```
```css
@import '@clerk/ui/themes/shadcn.css';
```

## Common Pitfalls

| Severity | Issue | Fix |
|----------|-------|-----|
| CRITICAL | Missing `await` on `auth()` | Next.js 15+: `auth()` is async |
| CRITICAL | Secret key in client code | Only `NEXT_PUBLIC_*` keys client-safe |
| HIGH | ClerkProvider wrapping `<html>` | Must be inside `<body>` |
| HIGH | Auth routes not public | Allow `/sign-in`, `/sign-up` in middleware |
| MEDIUM | Wrong import path | Server: `@clerk/nextjs/server`, Client: `@clerk/nextjs` |

## Custom Signup Forms

When building custom Clerk signup forms (not the prebuilt `<SignUp />`), always include CAPTCHA:
```tsx
<SignUp.Captcha className="empty:hidden" />
```
Place before the submit button. The prebuilt `<SignUp />` component handles this automatically.

## Webhooks (Svix)

Clerk sends webhooks via Svix. Verify signature in handler:
```ts
import { Webhook } from 'svix';
const wh = new Webhook(WEBHOOK_SECRET);
const event = wh.verify(body, headers);
```
Common events: `user.created`, `user.updated`, `user.deleted`, `session.created`.

## Requirements

- Node.js 20.9.0+
- Use Context7 MCP (`resolve-library-id` -> `query-docs`) for latest Clerk API patterns
