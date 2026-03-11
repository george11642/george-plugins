# Deep Interview: Socratic Requirements Gathering

Socratic questioning with mathematical ambiguity scoring. Replaces vague ideas with crystal-clear specifications by asking targeted questions that expose hidden assumptions, measuring clarity across weighted dimensions, and refusing to proceed until ambiguity drops below a configurable threshold (default: 20%).

## When to Use

- User has a vague idea and wants thorough requirements gathering before execution
- User says "deep interview", "interview me", "ask me everything", "don't assume"
- User says "socratic", "I have a vague idea", "not sure exactly what I want"
- Task is complex enough that jumping to code would waste cycles on scope discovery

## When NOT to Use

- User has a detailed, specific request with file paths, function names, or acceptance criteria
- User wants to explore options or brainstorm
- User wants a quick fix or single change
- User says "just do it" or "skip the questions"
- User already has a PRD or plan file

## Execution Rules

- Ask ONE question at a time — never batch multiple questions
- Target the WEAKEST clarity dimension with each question
- Gather codebase facts via Explore agent BEFORE asking the user about them
- Score ambiguity after every answer — display the score transparently
- Do not proceed to execution until ambiguity <= threshold (default 0.2)
- Allow early exit with a clear warning if ambiguity is still high

## Phase 1: Initialize

1. Parse the user's idea
2. Detect brownfield vs greenfield (spawn Explore agent to check for existing source code)
3. For brownfield: map relevant codebase areas
4. Announce the interview with initial idea, project type, and 100% ambiguity score

## Phase 2: Interview Loop

Repeat until `ambiguity <= threshold` OR user exits early.

### Clarity Dimensions

| Dimension | Weight (Greenfield) | Weight (Brownfield) | Question Style |
|-----------|-------------------|---------------------|----------------|
| Goal Clarity | 0.40 | 0.35 | "What exactly happens when...?" |
| Constraint Clarity | 0.30 | 0.25 | "What are the boundaries?" |
| Success Criteria | 0.30 | 0.25 | "How do we know it works?" |
| Context Clarity | N/A | 0.15 | "How does this fit?" |

### Ambiguity Calculation

- Greenfield: `ambiguity = 1 - (goal * 0.40 + constraints * 0.30 + criteria * 0.30)`
- Brownfield: `ambiguity = 1 - (goal * 0.35 + constraints * 0.25 + criteria * 0.25 + context * 0.15)`

### Progress Display

After each round, show:
```
Round {n} complete.

| Dimension | Score | Weight | Weighted | Gap |
|-----------|-------|--------|----------|-----|
| Goal | {s} | {w} | {s*w} | {gap or "Clear"} |
| Constraints | {s} | {w} | {s*w} | {gap or "Clear"} |
| Success Criteria | {s} | {w} | {s*w} | {gap or "Clear"} |
| Context (brownfield) | {s} | {w} | {s*w} | {gap or "Clear"} |
| **Ambiguity** | | | **{score}%** | |
```

## Phase 3: Challenge Agents

At specific round thresholds, shift the questioning perspective:

| Round | Mode | Purpose | Example |
|-------|------|---------|---------|
| 4+ | Contrarian | Challenge core assumptions | "What if the opposite were true?" |
| 6+ | Simplifier | Remove complexity | "What's the simplest version that would still be valuable?" |
| 8+ | Ontologist | Find the essence (if ambiguity > 0.3) | "What IS this, really?" |

Each challenge mode is used ONCE, then return to normal Socratic questioning.

## Phase 4: Crystallize Spec

When ambiguity <= threshold (or hard cap / early exit), generate specification:

- Metadata (rounds, final score, type, status)
- Clarity breakdown table
- Crystal-clear goal statement
- Constraints and non-goals
- Testable acceptance criteria
- Assumptions exposed and resolved
- Technical context
- Full interview transcript (in collapsible details)

## Phase 5: Execution Bridge

Present options:
1. Execute with current mode — hand off spec to active framework
2. Refine further — continue interviewing

## Soft Limits

- Round 3+: Allow early exit if user says "enough", "let's go", "build it"
- Round 10: Show soft warning about round count
- Round 20: Hard cap — proceed with current clarity level
- Ambiguity stalls (same score for 3 rounds): activate Ontologist mode
- All dimensions at 0.9+: skip to spec generation
