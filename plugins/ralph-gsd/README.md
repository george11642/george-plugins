# ralph-gsd

Autonomous milestone execution orchestrator for Claude Code.

Combines the Ralph loop technique with GSD (Get-Shit-Done) workflow to execute entire milestones without manual intervention.

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
/ralph-gsd:run --skip-discuss --max-iterations 50
```

### 3. Review deferred items

After completion, check `.planning/DEFERRED.md` for any items that need human review.

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--project-dir PATH` | Project directory | Current directory |
| `--max-iterations N` | Safety limit | 100 |
| `--skip-discuss` | Skip discuss phase, use defaults | false |
| `--dry-run` | Preview without executing | false |

## How It Works

1. Reads `.planning/STATE.md` and `ROADMAP.md` to detect current phase status
2. Determines next action: discuss → plan → execute → verify
3. Spawns Claude sessions with appropriate GSD commands
4. Loops until milestone complete or max iterations reached
5. Logs deferred checkpoints to `DEFERRED.md` for later review

## Files Created

- `.planning/ralph-gsd.log` - Execution log
- `.planning/DEFERRED.md` - Items needing human review

## Safety Features

- Max iteration limit (default 100)
- Stuck detection (3 repeats without progress)
- Deferred checkpoint handling (continues without blocking)

## Author

George Teifel
