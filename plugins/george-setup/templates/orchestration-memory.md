# Orchestration Memory

<!-- Installed by george-setup plugin. Add your own learnings below. -->

Auto-loaded by george-setup SessionStart hook. Read this file at the start of every session for orchestration rules.

**Tiers are cumulative** — each tier composes all lower tiers internally. A T4 Ralph loop dispatches phases that use T1/T2 agents; a T3 agent team coordinates T1/T2 work. You pick the **entry point** based on overall task complexity; the orchestration layer within that tier uses lower tiers as building blocks.

```
T4 Ralph Loop
 └─ dispatches phases via T1/T2/T3
     └─ T3 Agent Team coordinates T1/T2 agents
         └─ T1/T2 agents execute T0 inline edits
```

## Pre-Flight Checklist (EVERY T1+ TASK — DO THIS FIRST)

Before reading any files, before spawning any agents, before writing any code:

**Step 0a**: Scan available skills list → invoke domain-relevant skills (e.g. React UI → `building-native-ui`, `nextjs-app-router-patterns`). Skip routing/process skills (superseded by T0-T4).

**Step 0b**: Use Context7 when unsure about a library API or using it for the first time. Call `resolve-library-id` → `query-docs`. Skip for patterns used repeatedly in this codebase.

**Step 0c**: Every agent prompt MUST include:
> "BEFORE implementing: (1) Scan your available skills list and invoke any domain-relevant skills. (2) Use Context7 MCP — call resolve-library-id then query-docs — for [LIBRARY] docs. Do not implement library APIs from memory."

IF YOU SKIPPED ANY PART, STOP. GO BACK. DO IT NOW.

## T0: Inline Execution
- **When**: Single edit, obvious fix, <5 lines changed
- **How**: Main agent executes directly. No TaskCreate, no agent spawn.
- **Examples**: Fix typo, rename variable, add import, toggle flag

## T1: Single Agent (composes T0)
- **When**: One domain, bounded scope, 1-3 files
- **How**: `Task` with appropriate `subagent_type` and `model: "sonnet"`
- **subagent_type options**: `general-purpose` (default, full edit), `Explore` (search/read-only), `Plan` (architecture, read-only), or any plugin agent
- **Examples**: Implement a function, fix a bug, write tests for a module

## T2: Parallel Agents (composes T0–T1)
- **When**: Multiple independent domains, NO shared files, NO cross-agent dependencies
- **How**: Multiple `Task` calls in ONE message — all run concurrently, all return before continuing
- **Limit**: 2-5 parallel agents
- **Key constraint**: Agents can't message each other — fire-and-forget only. If you need coordination, use T3.
- **Examples**: Research 3 topics simultaneously, run tests + lint + type-check in parallel

## T3: Agent Team — THE DEFAULT FOR REAL WORK (composes T0–T2)

**Use T3 more often than you think.** Teams are the right choice for most non-trivial tasks.

### Why Teams Beat Parallel Agents
| Advantage | T2 (Parallel) | T3 (Team) |
|-----------|---------------|-----------|
| Context windows | Shared with main agent queue | **Independent per teammate** |
| Coordination | None — fire and forget | **Messaging + shared task list** |
| File conflicts | Must manually avoid overlap | **Assign file ownership** |
| Sequential dependencies | Impossible — all run at once | **Task dependency graph** |
| Sub-agent spawning | Cannot spawn nested agents | **Teammates can spawn T0/T1** |
| Progress tracking | No visibility until return | **TaskList shows live status** |
| Error recovery | Agent fails silently | **Lead can reassign/redirect** |

### When to Use T3
- Cross-domain work (frontend + backend, schema + worker, etc.)
- 3+ agents needed for a task
- Research that should feed into implementation
- One agent's output informs another's work
- Shared files that need ownership coordination
- Work requiring review/challenge between agents (use `mode: "plan"` on teammates)
- **When in doubt between T2 and T3 → choose T3**

### T3 Workflow
```
1. TeamCreate { team_name, description }
2. TaskCreate (×N) for each work unit (populate BEFORE spawning)
3. TaskUpdate addBlockedBy/addBlocks to set dependencies
4. Task (×N) with team_name + name params → spawn teammates
5. Lead assigns tasks via TaskUpdate { owner: "agent-name" }
6. Teammates: TaskList → claim → work → TaskUpdate completed → SendMessage to lead
7. Lead: receives messages automatically, reassigns or synthesizes
8. SendMessage { type: "shutdown_request" } to each teammate
9. TeamDelete
```

### Spawning Teammates
```json
{
  "subagent_type": "general-purpose",  // Explore/Plan = read-only, general-purpose = full edit
  "team_name": "feature-x",           // MUST match TeamCreate name
  "name": "backend-impl",             // human-readable, used for messaging + task ownership
  "model": "sonnet",                  // execution agents use sonnet
  "prompt": "You are the backend implementer. Check TaskList for your assigned tasks..."
}
```

### Key Capabilities (beyond system prompt defaults)
- **Plan approval**: Set `mode: "plan"` on a teammate → they must get lead approval before implementing
- **Worktree isolation**: Set `isolation: "worktree"` → agent works on isolated repo copy (auto-cleaned if no changes)
- **Agent resumption**: Pass `resume: "<agent_id>"` to continue a previous agent with full context
- **Team config discovery**: Teammates read `~/.claude/teams/{team-name}/config.json` for member list (name, agentId, agentType)
- **Peer DMs**: Teammates can message each other directly by name (lead gets summary in idle notification)
- **Nesting**: Teammates can spawn their own synchronous `Task` agents (depth=2, no `run_in_background`/`team_name`/`name`)

### Rules
- Always populate TaskCreate BEFORE spawning teammates — agents need tasks to claim
- Never assign the same file to two teammates — assign file ownership explicitly
- Prefer tasks in ID order (lowest first) — earlier tasks set up context for later ones
- Teammates go idle between turns — this is NORMAL. Send message to wake them.
- Teammates MUST use `SendMessage` to communicate — plain text output is invisible to others

## T4: Ralph Loop (composes T0–T3)
- **When**: Milestone-scale iterative work with clear completion criteria
- **How**: `/ralph-gsd:run` for full milestones, `/gsd:execute-phase` for single phases
- **Internally**: Each phase is dispatched as T1/T2/T3 work depending on complexity
- **Cost warning**: Ralph loops can burn $50-100+ in API costs. Always mention estimated iteration count.
- **Related skills**: `/gsd:new-project`, `/gsd:new-milestone`, `/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:verify-work`, `/gsd:progress`

## Tier Escalation
- If T1 proves insufficient (too many files, coordination needed) → escalate to T3 (skip T2 if coordination matters)
- If T2 agents need each other's output or touch shared files → escalate to T3
- If a task needs iterative refinement (TDD cycles, migration waves) → consider T4
- Escalation is normal — the initial tier assessment is a best guess

## Background vs Foreground
- **Foreground** (default): Agent blocks until complete. Results available immediately.
- **Background** (`run_in_background: true`): Runs async. Check via `TaskOutput`.
  - Use for: test suites, builds, linting, type checking
  - Cannot use: MCP tools, AskUserQuestion

## Agent Type Quick Reference
| Task Type | subagent_type |
|-----------|---------------|
| Code search, file exploration | `Explore` (read-only) |
| General implementation | `general-purpose` (full edit access) |
| Architecture planning | `Plan` (read-only) |
| Frontend/React work | `frontend-developer` or `mobile-developer` |
| Debugging | `debugger` |
| Test writing | `test-automator` |
| Code review | `code-reviewer` |
| Security audit | `security-auditor` |
| Database work | `database-architect` or `sql-pro` |

## Model Strategy
- **Main agent (orchestrator)**: Opus — routing, planning, architecture decisions only
- **Execution agents (T1+)**: Always `model: "sonnet"` for implementation work
- **Research/Explore agents**: `model: "haiku"` always. Only escalate to `"sonnet"` if haiku fails or the exploration requires multi-step reasoning
- **Exception**: `model: "opus"` only for complex reasoning (architecture, gnarly debugging)

## MCP Tools (USE THEM — not optional)

MCPs are lazy-loaded with zero context cost. Use them as your default, not as a fallback.

| Trigger | MCP Action |
|---------|------------|
| Using any external library API | **Context7**: `resolve-library-id` → `query-docs` with specific topic |
| Need to verify UI works | **Playwright** or **Superpowers Chrome**: take screenshot, check DOM |
| Clerk auth work | **Clerk MCP**: `clerk_sdk_snippet` for code examples |
| Sentry errors/monitoring | **Sentry MCP**: `search_issues`, `get_issue_details` |
| Task involves an external service | **ToolSearch** first — an MCP may already exist for it |
| Writing tests for a framework | **Context7**: query latest testing patterns/API |

## Post-Task Verification (every T1+ task — DO NOT SKIP)
After completing any T1+ task, do ALL of these:
1. **Run tests**: `pnpm test` (or relevant test command). Not optional.
2. **Type-check**: `pnpm type-check` if TypeScript was touched.
3. **Screenshot**: If the task changed UI, use Playwright or Superpowers Chrome to screenshot the page and verify it renders correctly.
4. **Cross-system check**: If you touched system A that connects to system B, verify B still works.

Failure → diagnose → fix → re-verify (max 2 retries before escalating to user).

## Error Recovery
1. First failure: diagnose root cause, fix inline
2. Second failure (same issue): step back, try alternative strategy
3. Third failure: escalate to user with diagnosis + 2-3 options
4. **Never** brute-force retry the same failing approach

## Context Protection Hard Limits (per response)
- **Max 2 file reads** — only files you're about to edit in the same response
- **Max 1 Grep/Glob** — if you need more, spawn Explore agent
- **Output ≤15 lines** to the user unless they asked for an explanation
- **Verification reads are allowed** after agents complete work — this does NOT extend to exploratory reads

## Skills Integration — What Works, What's Superseded

The Superpowers plugin ships skills that define their own orchestration pipeline (`brainstorming → writing-plans → subagent-driven-dev/executing-plans → finishing-branch`). This pipeline is **superseded** by the T0-T4 tier system. The tier system is the single source of truth for routing, model selection, and context protection.

### Superseded (never invoke)
`subagent-driven-development`, `executing-plans`, `using-superpowers`, `finishing-a-development-branch`

### Cherry-pick only
- `brainstorming` — question techniques only
- `writing-plans` — task format only
- `dispatching-parallel-agents` — prompt structure tips only

### Complementary Skills (use freely)

| Skill | Value Add |
|-------|-----------|
| `/systematic-debugging` | Scientific debugging methodology — hypothesis → test → narrow |
| `/test-driven-development` | TDD red-green-refactor discipline |
| `/verification-before-completion` | Evidence-before-claims checklist — prevents premature "done" claims |
| `/requesting-code-review` | Code review prompt template for spawning reviewer agents |
| `/receiving-code-review` | How to process code review feedback |
| `/using-git-worktrees` | Git worktree mechanics (when `isolation: "worktree"` is used) |

## Self-Check (before every T1+ response)
- [ ] Did I scan skills and invoke relevant domain skills? If not → do it now.
- [ ] Did I run Context7 for every external library? If not → do it now.
- [ ] Did every agent prompt include the Step 0c block? If not → add it.
- [ ] Did I pick the right tier? Cross-domain = T3, not T2.
- [ ] After agents finished: did I run tests? If not → run them now.
- [ ] After agents finished: did I screenshot UI changes? If not → do it now.
- [ ] Is my output ≤15 lines (unless user asked for explanation)?
