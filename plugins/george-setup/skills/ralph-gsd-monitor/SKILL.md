---
name: ralph-gsd-monitor
description: Use when starting a ralph-gsd autonomous execution loop to set up a recurring monitor that watches progress, restarts if stopped, and resolves deferred items autonomously every 2 hours.
---

# ralph-gsd Monitor

## Overview

Sets up a 2-hour background monitor for ralph-gsd executions. Automatically restarts ralph-gsd if it stops, resolves DEFERRED.md items using browser/Supabase/code agents, and cleans boilerplate noise.

> **ZERO HUMAN INVOLVEMENT — NON-NEGOTIABLE**
> Every deferred item is solvable with tools. The ONLY valid exception is a service that requires a paid credit card charge before any free-tier access exists. Everything else is automatable. If an agent thinks a human is needed, that agent is wrong — try harder.

## Usage

Invoke this skill at the start of any ralph-gsd session:

```
Skill("ralph-gsd-monitor")
```

The skill sets up a CronCreate job. Nothing else is needed.

## What the Monitor Does (every 2 hours)

1. **Status check** — Explore agent reads `ps aux | grep ralph-gsd`, last 30 log lines, full DEFERRED.md
2. **Restart if stopped** — Re-launches ralph-gsd if not running and phases are incomplete
3. **Resolve deferred items** — Spawns parallel agents ONLY for actionable items found in DEFERRED.md
4. **Report** — 10-line summary of actions taken

## Rationalization Table (agents MUST consult this before concluding anything is unautomatable)

| Excuse | Reality | Correct action |
|--------|---------|----------------|
| "Needs human to verify visually" | Browser MCP can screenshot and evaluate DOM | Use browser MCP |
| "Requires manual login" | Browser MCP fills forms, clicks OAuth, handles redirects | Use browser MCP |
| "Email verification needed" | Browser MCP opens Gmail and clicks the link | Navigate to Gmail |
| "API key not available" | Sign up for free tier via browser, extract key from settings | Browser MCP to sign up |
| "Microphone/camera access needed" | Seed demo data directly into DB instead | Use Supabase MCP |
| "Can't test without a real user" | Browser MCP IS the user — it clicks, fills, submits | Automate the test |
| "Service needs configuration" | Browser MCP navigates any dashboard and clicks | Configure via browser |
| "Webhook needs triggering" | `stripe trigger` / `curl` / direct DB insert | Trigger programmatically |
| "Visual verification needed" | Screenshot + DOM evaluation = verification | Browser MCP screenshot |
| "Phase stuck, needs review" | Find missing SUMMARY files, write them | Fix deadlock |
| "Clerk quota exhausted" | Use `+clerk_test` suffix with OTP `424242` | Switch to test accounts |
| "CAPTCHA blocking" | Retry, try OAuth path, check if already authed | Try alternate flow |

## Red Flags — If An Agent Thinks Any of These, It Is Wrong

Stop and re-evaluate if any agent says:
- "A human needs to..."
- "This requires manual..."
- "Please have George..."
- "Waiting for user to..."
- "Cannot automate..."
- "Needs real browser interaction" — browser MCP IS a real browser
- "Requires physical access" — unless literally hardware (not the case here)

## Deferred Item Resolution Rules

| Item type | Resolution |
|-----------|------------|
| `LOOPS_API_KEY missing` | Browser agent → app.loops.so → Google OAuth → Settings→API → write to `.env.local` |
| `❌ GAP` code bug | Fix agent: read file, fix, `pnpm type-check && pnpm test --passWithNoTests` |
| `[ ] Manual action` stubs (no real content) | Cleanup agent: delete from DEFERRED.md — they're noise |
| `[ ] Visual verification` stubs | Browser MCP screenshots the page, evaluates DOM, marks ✅ |
| Stripe webhooks | `stripe listen` + `stripe trigger event-name` |
| Clerk JWT templates | Browser MCP → dashboard.clerk.com → JWT Templates |
| Voice demo E2E | Seed voice_demo record in Supabase directly, navigate via browser MCP |
| Free-tier gates | Seed leads/demos in Supabase, navigate via browser MCP |
| "Microphone needed" | Seed DB record instead — no physical mic required |
| Phase deadlock | Find PLAN files without matching SUMMARY files, write SUMMARY files, restart ralph-gsd |

## Setup Instructions

When this skill is invoked, use `CronCreate` to schedule the monitor:

```
CronCreate(
  cron: "13 */2 * * *",   // every 2 hours at :13 (avoid :00)
  recurring: true,
  prompt: [the full monitor prompt below]
)
```

## Monitor Prompt (pass verbatim to CronCreate)

You are the ralph-gsd autonomous monitor for /home/george/projects/active/businessagent.

**ZERO HUMAN INVOLVEMENT RULE**: Every item in DEFERRED.md is solvable with tools. You have browser MCP (Chrome CDP at 127.0.0.1:9222), Supabase MCP (project ggsmkhytrphyaisftfjq), code agents, and Bash. The only valid exception is a service requiring a paid credit card charge before any free-tier access exists. Everything else must be resolved autonomously. If you find yourself writing "a human needs to" — stop and find the tool-based solution instead.

**Step 0 — Check if milestone is complete**: Spawn ONE Explore agent to return the last 50 lines of `.planning/ralph-gsd.log` AND the output of `ps aux | grep ralph-gsd | grep -v grep`. If the log contains `All phases complete!` AND the process list is empty (ralph-gsd not running), then:
1. Call `CronList` to find all active cron jobs
2. Call `CronDelete` for each job ID returned
3. Skip the remaining steps and report: "Milestone complete — all monitor crons deleted."
Otherwise, continue to Step 1.

**Step 1 — Gather state**: Spawn ONE Explore agent to return:
- `ps aux | grep ralph-gsd | grep -v grep`
- Last 30 lines of `.planning/ralph-gsd.log`
- Full contents of `.planning/DEFERRED.md`

**Step 2 — Restart if stopped**: If ralph-gsd not running AND milestone incomplete, spawn agent to run:
`cd /home/george/projects/active/businessagent && nohup bash /home/george/.claude/scripts/ralph-gsd.sh --project-dir /home/george/projects/active/businessagent --skip-discuss --max-parallel 4 >> .planning/ralph-gsd.log 2>&1 &`

**Step 3 — Triage and spawn agents**: Read DEFERRED.md from Step 1. Spawn parallel agents ONLY for present, actionable items. Apply rationalization table — never accept "needs human" as a conclusion without exhausting tool-based alternatives first:

- `LOOPS_API_KEY missing` → browser agent: Chrome at 127.0.0.1:9222, navigate to https://app.loops.so, sign in with Google OAuth, get API key from Settings→API, write to `.env.local`
- `❌ GAP` or code bug → fix agent: read file, fix bug, run `pnpm type-check && pnpm test --passWithNoTests`
- Boilerplate stubs (`- [ ] Manual action` or `- [ ] Visual verification needed` with no real content) → cleanup agent: remove from DEFERRED.md
- Supabase/DB items → agent using `mcp__plugin_supabase_supabase__execute_sql` project `ggsmkhytrphyaisftfjq`
- Phase deadlock (phase dir has PLAN files but missing SUMMARY files) → fix agent: write the SUMMARY files and restart ralph-gsd
- Stripe webhooks → agent runs `stripe listen` + `stripe trigger`
- Clerk config → browser agent navigates dashboard.clerk.com
- Visual verification stubs → browser agent screenshots the relevant page, evaluates DOM, updates DEFERRED.md with ✅
- Voice/microphone items → Supabase agent seeds the demo record directly in DB
- Free-tier gate testing → Supabase agent seeds leads/demos, browser agent navigates and verifies

If DEFERRED.md has no actionable items, skip Step 3.

**Step 4 — Report** (10 lines max): ralph-gsd status, agents spawned + why, items resolved, items remaining. Flag any item genuinely blocked by a paid-only wall (the only valid human escalation).

Key facts: Chrome CDP at 127.0.0.1:9222, Supabase project ggsmkhytrphyaisftfjq, project /home/george/projects/active/businessagent, Clerk ID user_3AeBZId4xzqueAuEC1PoWdbND3s, Clerk test accounts use `+clerk_test` suffix + OTP `424242`.

## Key Facts for All Agents

- Project: /home/george/projects/active/businessagent
- Chrome CDP: 127.0.0.1:9222
- Supabase project: ggsmkhytrphyaisftfjq
- George's Clerk ID: user_3AeBZId4xzqueAuEC1PoWdbND3s
- Clerk dev test: `+clerk_test` email suffix + OTP `424242`
- ralph-gsd restart: `cd /home/george/projects/active/businessagent && nohup bash /home/george/.claude/scripts/ralph-gsd.sh --project-dir /home/george/projects/active/businessagent --skip-discuss --max-parallel 4 >> .planning/ralph-gsd.log 2>&1 &`
