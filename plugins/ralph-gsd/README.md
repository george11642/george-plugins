# ralph-gsd

Autonomous milestone execution orchestrator for Claude Code.

Combines the Ralph loop technique with GSD (Get-Shit-Done) workflow to execute entire milestones without manual intervention. v2.0 adds parallel phase execution based on dependency graphs.

## Prerequisites

- **GSD plugin installed** (`get-shit-done-cc` package)
- Project with `.planning/` directory (created by `/gsd:new-project` or `/gsd:new-milestone`)

## Installation

```
/plugin add-marketplace https://github.com/george11642/george-plugins
/plugin install ralph-gsd@george-plugins
```

## Usage

### 1. Create a milestone with GSD

```
/gsd:new-project "My Feature"
```

### 2. Start autonomous execution

```
/ralph-gsd:run
```

Or with options:
```
/ralph-gsd:run --skip-discuss --max-iterations 50 --max-parallel 3
```

### 3. Review deferred items

After completion, `.planning/DEFERRED.md` items are processed **autonomously** by `process_deferred_items()` using browser agents, fix agents, and code agents — no human action needed.

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--project-dir PATH` | Project directory | Current directory |
| `--max-iterations N` | Safety limit | 100 |
| `--max-parallel N` | Max concurrent Claude sessions | 4 |
| `--skip-discuss` | Skip discuss phase, use defaults | false |
| `--dry-run` | Preview without executing | false |

## How It Works

1. Reads `.planning/STATE.md` and `ROADMAP.md` to detect current phase status
2. **Parses dependency graph** from `**Depends on**: Phase N` lines in ROADMAP.md
3. Determines all phases where dependencies are met (ready phases)
4. **Dispatches independent phases in parallel** (up to `--max-parallel`)
5. Falls back to sequential execution when only one phase is ready
6. Loops until milestone complete, deadlock, or max iterations reached
7. Logs deferred checkpoints to `DEFERRED.md`; these are processed autonomously by `process_deferred_items()` at milestone completion

## Parallel Execution

Ralph parses the `**Depends on**` lines in your ROADMAP.md to build a dependency graph. Phases whose dependencies are all verified get dispatched simultaneously.

Example dependency graph:
```
Phase 19 → Phase 20 ──┐
         → Phase 21 ──┼→ 22 → 23 → 24 → 25 → 26
```

After Phase 19 verifies, Ralph dispatches Phase 20 and 21 in parallel. Phase 22 starts when 21 verifies (doesn't wait for 20).

### File Contention

Parallel phases write to different `phases/NN-*/` directories. Low risk on STATE.md/ROADMAP.md since each phase updates its own row. File locking can be added in a future version if needed.

## Files Created

- `.planning/ralph-gsd.log` - Execution log
- `.planning/DEFERRED.md` - Items processed autonomously by `process_deferred_items()` (browser/fix/code agents — no human needed)
- `.planning/ralph-gsd-parallel/` - Per-phase log files (during parallel execution)

## Safety Features

- Max iteration limit (default 100)
- Max parallel sessions limit (default 4)
- Per-phase stuck detection (3 repeats without progress → phase skipped)
- Deadlock detection (no ready phases but milestone incomplete)
- Deferred checkpoint handling (continues without blocking)

## Author

George Teifel
