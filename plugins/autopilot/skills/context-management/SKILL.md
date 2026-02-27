---
name: context-management
description: "Auto-triggers when context is getting large or when running long sessions. Provides smart context management: when to write handoff files, how to structure state for session chaining, how to spawn fresh sessions. Activates on: long session, context pressure, session handoff, memory management, running out of context."
version: 1.0.0
---

# Context Management for Long-Running Sessions

## The Core Problem
LLMs degrade gradually starting around 30K tokens. Information in the middle of context is recalled 10-40% worse than at the edges. After ~100K tokens, you're operating at reduced capacity.

## Prevention: Keep Context Lean

### File Reading
- Read only files you're about to edit
- Use Grep to find specific patterns instead of reading whole files
- Spawn subagents for exploratory reading — their context is separate

### Subagent Isolation
- Each subagent gets its own fresh context window
- Send them specific instructions, get back structured results
- The main agent's context only grows by the summary, not the raw exploration

### Progressive Disclosure
- Start with file names (Glob)
- Then search for patterns (Grep)
- Then read specific lines (Read with offset/limit)
- Only read the full file when you're ready to edit it

## Detection: Know When Context Is Full

Warning signs that you're approaching limits:
- You've been working for 20+ tool calls without spawning subagents
- You've read more than 10 files in the current session
- You're re-reading files you read earlier (sign of context loss)
- Your responses are getting less specific or accurate

## Recovery: The Handoff Protocol

When you detect context pressure, write a handoff file:

### `.autopilot/handoff.md` Structure
```markdown
# Handoff — [Timestamp]

## Current Task
[What I was working on]

## What's Done
- [Completed item 1]
- [Completed item 2]

## What's Left
- [Remaining item 1 with specific file:line references]

## Key Context
- [Critical fact 1 that the next session MUST know]
- [Critical fact 2]

## Failed Approaches
- Tried [X], failed because [Y] — DO NOT retry

## Files Modified This Session
- `path/to/file.ts` — [what changed]

## Environment State
- Branch: [current branch]
- Tests: [passing/failing]
- Uncommitted changes: [yes/no, what]
```

### What Makes a Good Handoff
1. **Concrete, not narrative**: File paths and line numbers, not stories
2. **Failed approaches**: The most valuable section — prevents re-doing dead ends
3. **Actual code snippets**: For complex logic, include the key 5-10 lines
4. **Decision rationale**: Not just "chose X" but "chose X because Y"
5. **Verification state**: What tests pass, what's broken

### What to Omit
- General knowledge about the codebase (it's in CLAUDE.md)
- Full file contents (they're on disk)
- Explanations of how tools work
- Narrative of the session ("First I tried...")

## The Manus Pattern: Todo Recitation

For very long sessions, periodically rewrite your current task state to keep it fresh at the context boundary:
- Every 10 tool calls, mentally review: "What am I doing? What's left?"
- Write current state to handoff.md even if you're not switching sessions
- This fights the "lost in the middle" effect
