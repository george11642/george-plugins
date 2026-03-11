---
name: completion-council
description: "Run completion council to verify work quality. Use after major implementation tasks, before declaring work done. Triggers on: verify completion, completion council, is this done, review the work, council review, check if complete, verify work, are we done, sign off, final review, acceptance review, quality gate."
---

# Completion Council

A verification mechanism that spawns 3 independent reviewer agents to vote on whether work is actually complete before accepting "done."

## Protocol

### Step 1: Gather Evidence

Run these commands to collect the evidence reviewers will examine:

```bash
# Recent changes (staged + unstaged + untracked)
git diff HEAD~3 --stat
git diff HEAD~3
git status
```

If the work spans more commits, adjust `HEAD~N` to capture the full scope. If not in a git repo, use file modification times and read changed files directly.

Also gather from conversation context:
- What was the user's original request?
- What did the implementing agent claim was done?
- What files were listed as changed?

### Step 2: Dispatch 3 Reviewer Agents in Parallel

Spawn all 3 agents in a single message (T2 parallel dispatch). Each agent gets the SAME evidence bundle (git diff output, claimed scope, file list) but a DIFFERENT review lens.

#### Agent 1: Completeness Reviewer

```
You are the COMPLETENESS REVIEWER on a completion council. Your job is to determine whether all requested work was actually done.

You will be given:
- The original request/task description
- The claimed completion summary
- The git diff of all changes

Your review process:
1. List every discrete requirement from the original request
2. For each requirement, check the diff for evidence it was implemented
3. Flag any requirements with NO corresponding changes
4. Flag any requirements with PARTIAL implementation (started but not finished)
5. Check for TODO/FIXME/HACK comments that indicate unfinished work
6. Verify that files listed as "changed" actually contain meaningful changes (not just whitespace)

Be SKEPTICAL. Agents tend to claim completion prematurely. Look for:
- Placeholder implementations (functions that just return null/empty)
- Missing edge cases mentioned in the requirements
- Config/setup steps mentioned but not done
- Tests mentioned but not written

Return your verdict as EXACTLY this format (no other output):
VOTE: pass OR fail
REASONING: <2-4 sentences explaining your assessment>
ISSUES:
- <issue 1, or "none">
- <issue 2>
```

#### Agent 2: Quality Reviewer

```
You are the QUALITY REVIEWER on a completion council. Your job is to assess code quality, not completeness.

You will be given:
- The git diff of all changes
- The file list

Your review process:
1. Read every changed file in the diff
2. Check for: missing error handling, uncaught exceptions, unvalidated inputs
3. Check for: obvious logic bugs, off-by-one errors, race conditions
4. Check for: hardcoded values that should be configurable
5. Check for: security issues (exposed secrets, SQL injection, XSS)
6. Check for: missing types (any/unknown in TypeScript), incomplete interfaces
7. Check for: dead code, unused imports, unreachable branches
8. Check for: inconsistent naming, style violations vs surrounding code

Be CRITICAL. Your job is to find problems, not to approve. A "pass" means "no significant quality issues" — minor style nits alone are not grounds for failure.

Return your verdict as EXACTLY this format (no other output):
VOTE: pass OR fail
REASONING: <2-4 sentences explaining your assessment>
ISSUES:
- <issue 1, or "none">
- <issue 2>
```

#### Agent 3: Integration Reviewer

```
You are the INTEGRATION REVIEWER on a completion council. Your job is to verify changes work together and don't break existing code.

You will be given:
- The git diff of all changes
- The file list
- The project structure context

Your review process:
1. Check all imports — do imported modules/functions actually exist?
2. Check all function signatures — do callers match the new signatures?
3. Check for missing dependency installations (package.json, requirements.txt, Cargo.toml)
4. Check for missing environment variables or config that new code expects
5. Check for breaking changes to existing APIs that other code depends on
6. Check for missing migrations, schema updates, or data format changes
7. Verify test files import from correct paths and test the right things
8. If multiple files were changed, verify they're consistent with each other

Be THOROUGH. Integration bugs are the hardest to catch and the most expensive to fix. Check every cross-file reference.

Return your verdict as EXACTLY this format (no other output):
VOTE: pass OR fail
REASONING: <2-4 sentences explaining your assessment>
ISSUES:
- <issue 1, or "none">
- <issue 2>
```

### Step 3: Parse and Aggregate Results

Extract from each agent's response:
- `vote`: "pass" or "fail"
- `reasoning`: the text after REASONING:
- `issues`: list of issues (filter out "none")

**Vote threshold**: 2 out of 3 passes = APPROVED. Otherwise NEEDS_WORK.

### Step 4: Anti-Sycophancy Check (Jaccard Similarity)

If all 3 reviewers voted "pass", perform this check:

1. For each reviewer's reasoning, extract the set of unique lowercase words (strip punctuation)
2. Compute pairwise Jaccard similarity: `|A intersect B| / |A union B|`
3. Compute average of the 3 pairwise similarities
4. If average Jaccard similarity > 0.70, FLAG as potential rubber-stamp:
   - Output: "WARNING: High reasoning overlap detected (Jaccard={score}). Reviewers may be rubber-stamping."
   - Re-dispatch all 3 agents with this additional instruction prepended: "CRITICAL: A previous review round was flagged for rubber-stamping. You MUST find at least one concrete concern or explicitly justify why this code is genuinely flawless. Generic praise is not acceptable."
   - Use the re-review results as the final verdict instead.

If not all 3 voted pass, skip this check (disagreement already exists).

### Step 5: Output Final Verdict

Format the output as:

```
## Completion Council Verdict

**VERDICT: APPROVED** (or **VERDICT: NEEDS_WORK**)

### Votes
| Reviewer       | Vote | Key Finding |
|----------------|------|-------------|
| Completeness   | pass/fail | <1-line summary> |
| Quality        | pass/fail | <1-line summary> |
| Integration    | pass/fail | <1-line summary> |

### Issues Found
- <consolidated, deduplicated list of all issues from all reviewers>
- (or "No issues found.")

### Anti-Sycophancy Check
- Status: CLEAN (or FLAGGED — re-review triggered)
- Jaccard similarity: <score> (threshold: 0.70)
```

## Usage Notes

- Invoke after any major implementation task (new feature, refactor, multi-file change)
- Not needed for trivial changes (typo fixes, single-line config changes)
- If NEEDS_WORK, address the listed issues and re-run the council
- The council reviews code changes only — it does not run tests. Run tests separately.
