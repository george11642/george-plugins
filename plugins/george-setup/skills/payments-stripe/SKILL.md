---
name: payments-stripe
description: "Use when integrating Stripe payments, subscriptions, checkout, webhooks, or billing. Triggers on Stripe, Stripe checkout, Stripe subscription, Stripe webhook, invoice.paid, customer.subscription.deleted, Stripe test card, 4242, Stripe Connect, Stripe Customer Portal, Stripe pricing table, trial period, webhook signature, idempotency key, Stripe SDK, use node Stripe."
---

# Payments Stripe

## Key Patterns
- Stripe SDK requires `"use node"` directive in Convex actions
- Split Stripe logic into separate files from V8 queries/mutations
- Webhook signature verification in your HTTP actions file

## Test Cards
| Scenario | Card Number |
|----------|------------|
| Success | 4242 4242 4242 4242 |
| Decline | 4000 0000 0000 0002 |
| 3D Secure | 4000 0027 6000 3184 |
| Insufficient funds | 4000 0000 0000 9995 |

## Subscription Flow
1. Create Checkout Session → redirect to Stripe
2. Webhook `checkout.session.completed` → update DB
3. Webhook `invoice.paid` → extend subscription
4. Webhook `customer.subscription.deleted` → revoke access

## Gotchas
- Trial periods: set `trial_period_days` on price, not subscription
- Webhook events arrive out of order — use idempotency keys
- Always verify webhook signature before processing
- Stripe MCP available via ToolSearch for complex operations
