---
name: deploy-vercel
description: "Use when deploying to Vercel, managing Vercel deployments, or configuring Vercel environment variables. Triggers on deploy to Vercel, Vercel deploy, vercel --prod, Vercel preview, Vercel env, Vercel logs, Vercel build, Vercel deployment, vercel ls, custom domain Vercel, 504 timeout serverless, Vercel rollback, pull env, NEXT_PUBLIC, Vercel serverless function."
---

# Deploy Vercel

Check project CLAUDE.md for project ID and configuration.

## Commands
| Task | Command |
|------|---------|
| Deploy preview | `vercel` |
| Deploy production | `vercel --prod` |
| List deployments | `vercel ls --limit 5` |
| View logs | `vercel logs [url]` |
| Set env var | `vercel env add NAME` |
| Pull env | `vercel env pull .env.local` |

## Patterns
- Preview URL auto-generated on every push
- Production deploys on merge to main
- Environment: `NEXT_PUBLIC_*` for client-side vars
- Serverless functions in `app/api/` (Next.js App Router)

## Troubleshooting
- Build fails: check `vercel logs [deploy-url]`
- 504 timeout: serverless function >10s, consider streaming
- Missing env vars: `vercel env ls` to verify
