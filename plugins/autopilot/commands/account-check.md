---
name: account-check
description: Verify service credentials and auth state for autonomous operations
argument: "[--service NAME]"
---

# Account Check

Verifies that service credentials are configured and valid for autonomous SaaS operations.

## Usage

```
/autopilot:account-check
/autopilot:account-check --service stripe
```

## What This Does

1. Reads `~/.claude/account-inventory.json` for service configuration
2. For each service (or specified service):
   - Checks if required env vars are set
   - Validates credentials where possible (API health checks)
   - Reports auth status
3. Shows human gates status (KYC, domain purchase, etc.)

## Implementation

<execution_context>
Read the account inventory:
```bash
INVENTORY="$HOME/.claude/account-inventory.json"
```

If `$ARGUMENTS` contains `--service`, filter to that service only.

For each service in the inventory:
1. Check each env var: `[[ -n "${!var}" ]]`
2. Report: configured / missing
3. For services with API validation:
   - Stripe: `curl -s https://api.stripe.com/v1/balance -u "$STRIPE_SECRET_KEY:" | grep -q "available"`
   - Vercel: `vercel whoami 2>/dev/null`
   - GitHub: `gh auth status 2>/dev/null`

Show human gates section with status of each gate.

Output format:
```
Service Status:
  stripe: configured (KYC: pending)
  vercel: configured
  clerk: missing CLERK_SECRET_KEY
  github: authenticated
  ...

Human Gates:
  Stripe KYC — Complete identity verification
  Domain Purchase — Purchase and configure domain
```
</execution_context>
