# Playwright Auth (Clerk)

Authenticate Playwright browser sessions against Clerk-based apps using the Backend API sign-in token pattern. Bypasses password, MFA, and CAPTCHA entirely.

## Trigger

Use when: setting up Playwright auth for Clerk, authenticating E2E tests, creating auth setup files, or fixing Clerk auth in Playwright tests.

## Prerequisites

- `CLERK_SECRET_KEY` environment variable must be set (starts with `sk_test_` or `sk_live_`)
- Clerk user must exist (default: `e2e-dev@autoclip.dev`, ID `user_3ANMapHPUcEqIGMAHlQTz1bZkGA`)
- App must load Clerk JS on the frontend (`window.Clerk`)

## Auth Pattern

### Step 1: Create a Sign-In Token via Clerk Backend API

```typescript
const secretKey = process.env.CLERK_SECRET_KEY!;
const userId = 'user_3ANMapHPUcEqIGMAHlQTz1bZkGA'; // or look up by email

// Optional: look up user by email
const usersRes = await fetch(
  `https://api.clerk.com/v1/users?email_address=${encodeURIComponent('e2e-dev@autoclip.dev')}`,
  { headers: { Authorization: `Bearer ${secretKey}` } }
);
const users = await usersRes.json();
const userId = users[0]?.id;

// Create sign-in token (bypasses password + MFA + CAPTCHA)
const tokenRes = await fetch('https://api.clerk.com/v1/sign_in_tokens', {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${secretKey}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ user_id: userId }),
});
const { token: ticket } = await tokenRes.json();
```

### Step 2: Load the App and Wait for Clerk JS

```typescript
await page.goto('/');
await page.waitForLoadState('networkidle');
await page.waitForFunction(() => !!(window as any).Clerk?.loaded, { timeout: 15_000 });
```

### Step 3: Sign In with the Ticket

```typescript
const status = await page.evaluate(async (t: string) => {
  const clerk = (window as any).Clerk;
  try {
    const signIn = await Promise.race([
      clerk.client.signIn.create({ strategy: 'ticket', ticket: t }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('signIn timeout')), 30_000)
      ),
    ]) as any;
    if (signIn.status === 'complete') {
      await clerk.setActive({ session: signIn.createdSessionId });
      return signIn.status;
    }
    return signIn.status;
  } catch (e: any) {
    return 'error:' + e.message;
  }
}, ticket);

// status is null when setActive() triggered navigation that destroyed JS context — this is success
if (status !== null && !status.startsWith('complete')) {
  throw new Error(`Sign-in did not complete. Status: ${status}`);
}
```

### Step 4: Wait for Navigation and Save State

```typescript
import path from 'path';
import fs from 'fs';

// Wait for post-login redirect to settle
await page.waitForLoadState('domcontentloaded', { timeout: 8_000 }).catch(() => {});
if (!page.url().includes('/dashboard')) {
  await page.goto('/dashboard', { waitUntil: 'domcontentloaded' });
}

// Save auth state for reuse across tests
const authFile = path.join(__dirname, '../playwright/.auth/user.json');
fs.mkdirSync(path.dirname(authFile), { recursive: true });
await page.context().storageState({ path: authFile });
```

### Step 5 (Optional): Warm Convex JWT

If the app uses Convex with Clerk, warm the JWT cache so subsequent tests don't hit auth races:

```typescript
await page.waitForLoadState('networkidle');
await page.waitForFunction(async () => {
  const clerk = (window as any).Clerk;
  if (!clerk?.session) return false;
  try {
    const token = await clerk.session.getToken({ template: 'convex' });
    return !!token;
  } catch {
    return false;
  }
}, { timeout: 15_000 }).catch(() => { /* non-fatal */ });
```

## Playwright Config Integration

In `playwright.config.ts`, register the auth setup as a dependency:

```typescript
export default defineConfig({
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },
  ],
});
```

## Helper: Wait for Auth in Tests

After navigating to authenticated pages, wait for Clerk + any backend auth (e.g., Convex) to be ready:

```typescript
export async function waitForAuthReady(page: Page, timeout = 30_000) {
  await page.waitForFunction(
    async () => {
      const clerk = (window as any).Clerk;
      if (!clerk?.session) return false;
      try {
        const token = await clerk.session.getToken({ template: 'convex' });
        return !!token;
      } catch {
        return false;
      }
    },
    { timeout },
  );
}
```

## Gotchas

- **`page.evaluate` returns `null` on success**: When `clerk.setActive()` triggers a full-page navigation, the JS context is destroyed and `evaluate` returns `null`. Treat `null` as success.
- **Sign-in tokens are single-use**: Each call to `/v1/sign_in_tokens` creates a one-time token. Generate a fresh one per test run.
- **Clerk JS load timing**: Always `waitForFunction(() => window.Clerk?.loaded)` before calling Clerk APIs — the script loads async.
- **Storage state reuse**: Save `storageState` after auth setup so individual tests skip the sign-in flow entirely.
- **Convex JWT race**: Without warming the JWT in the setup step, the first Convex mutation in a test may fail with "Unauthenticated". Always include Step 5 if using Convex.
