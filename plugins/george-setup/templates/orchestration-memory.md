# Orchestration Memory

<!-- Installed by george-setup plugin. Add your own learnings below. -->

Linked from CLAUDE.md. See `~/.claude/CLAUDE.md` for the concise routing table.

**Tiers are cumulative** — each tier composes all lower tiers internally. A T4 Ralph loop dispatches phases that use T1/T2 agents; a T3 agent team coordinates T1/T2 work. You pick the **entry point** based on overall task complexity; the orchestration layer within that tier uses lower tiers as building blocks.

```
T4 Ralph Loop
 └─ dispatches phases via T1/T2/T3
     └─ T3 Agent Team coordinates T1/T2 agents
         └─ T1/T2 agents execute T0 inline edits
```

## T0: Inline Execution
- **When**: Single edit, obvious fix, <5 lines changed
- **How**: Main agent executes directly. No TaskCreate, no agent spawn.
- **Examples**: Fix typo, rename variable, add import, toggle flag

## T1: Single Agent (composes T0)
- **When**: One domain, bounded scope, 1-3 files
- **How**: `Task` with appropriate `subagent_type` and `model`
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

## Skills Integration — What Works, What's Superseded

The Superpowers plugin ships skills that define their own orchestration pipeline (`brainstorming → writing-plans → subagent-driven-dev/executing-plans → finishing-branch`). This pipeline is **superseded** by the T0-T4 tier system. The tier system is the single source of truth for routing, model selection, and context protection.

### Complementary Skills (use freely)
These add domain knowledge the tier system doesn't cover:

| Skill | Value Add |
|-------|-----------|
| `/systematic-debugging` | Scientific debugging methodology — hypothesis → test → narrow |
| `/test-driven-development` | TDD red-green-refactor discipline |
| `/verification-before-completion` | Evidence-before-claims checklist — prevents premature "done" claims |
| `/requesting-code-review` | Code review prompt template for spawning reviewer agents |
| `/receiving-code-review` | How to process code review feedback |
| `/using-git-worktrees` | Git worktree mechanics (when `isolation: "worktree"` is used) |

### Domain-Only Skills (use for domain knowledge, ignore orchestration)
These have useful techniques buried under conflicting routing advice:

| Skill | Use | Ignore |
|-------|-----|--------|
| `/brainstorming` | One-question-at-a-time technique, approach trade-off presentation | Hard-gate on implementation, mandatory `docs/plans/` saves, chain to `writing-plans` |
| `/dispatching-parallel-agents` | Agent prompt structure (scope, context, constraints, output format) | When-to-use decision tree (use T0-T4 instead) |

### Superseded Skills (do not invoke)
These define alternative orchestration systems that conflict with T0-T4:

| Skill | Why Superseded |
|-------|----------------|
| `/subagent-driven-development` | Defines its own implementer→spec-reviewer→quality-reviewer pipeline. T3 teams do this better with flexible coordination. |
| `/executing-plans` | Batch execution with human-in-loop checkpoints. Conflicts with high-autonomy user preference and T3/T4 execution. |
| `/writing-plans` | Assumes worktree workflow, saves to arbitrary `docs/plans/`, chains to superseded execution skills. Use `EnterPlanMode` instead. |
| `/using-superpowers` | Meta-skill that pressures invoking everything "even at 1% chance." Wastes context loading irrelevant skills. The CLAUDE.md skill section replaces it. |
| `/finishing-a-development-branch` | Assumes worktree workflow with 4-option menu. Project deploy rules (auto-commit, push, deploy) make this unnecessary. |
