---
name: run
description: Start autonomous milestone execution loop
argument-hint: "[--project-dir PATH] [--max-iterations N] [--max-parallel N] [--skip-discuss] [--dry-run]"
allowed-tools:
  - Bash
  - Read
---

# Ralph-GSD: Autonomous Milestone Execution

Run the ralph-gsd orchestrator to autonomously execute a GSD milestone.

## Prerequisites

- **GSD must be installed** (get-shit-done-cc package)
- Project must have `.planning/` directory with `ROADMAP.md` and `STATE.md`
- Create milestone first with `/gsd:new-project` or `/gsd:new-milestone`

## Usage

Run the orchestrator script from this plugin:

```bash
"$PLUGIN_DIR/scripts/ralph-gsd.sh" --project-dir "$(pwd)" [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--project-dir PATH` | Project directory with .planning/ (required) |
| `--max-iterations N` | Safety limit, default 100 |
| `--max-parallel N` | Max concurrent Claude sessions, default 4 |
| `--skip-discuss` | Auto-skip discuss phase with defaults |
| `--dry-run` | Show what would happen without executing |

## Execution Steps

1. Check that `.planning/ROADMAP.md` exists in the project
2. Run the script with appropriate options based on user request
3. The script parses dependency graph from ROADMAP.md
4. Independent phases are dispatched in parallel (up to --max-parallel)
5. Sequential fallback when only one phase is ready
6. Monitor output for completion or errors

## Example Commands

Start with defaults (current directory):
```bash
"$PLUGIN_DIR/scripts/ralph-gsd.sh" --project-dir "$(pwd)"
```

Skip discuss phases with parallel limit:
```bash
"$PLUGIN_DIR/scripts/ralph-gsd.sh" --project-dir "$(pwd)" --skip-discuss --max-parallel 2
```

Dry run to preview dependency graph:
```bash
"$PLUGIN_DIR/scripts/ralph-gsd.sh" --project-dir "$(pwd)" --dry-run
```

## Notes

- The script runs in the foreground and spawns new Claude sessions
- Parallel phases output to per-phase log files in `.planning/ralph-gsd-parallel/`
- Checkpoints are logged to `.planning/DEFERRED.md` for later review
- Execution log saved to `.planning/ralph-gsd.log`
- Script will stop on errors, deadlock, or after max iterations
