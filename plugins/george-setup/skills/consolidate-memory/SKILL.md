---
description: "Consolidate and deduplicate MEMORY.md. Use when memory file is getting large, has duplicates, or needs cleanup. Triggers on: consolidate memory, clean memory, deduplicate memory, memory cleanup."
---

# Memory Consolidation

Run the memory consolidation script to deduplicate and organize MEMORY.md.

## Instructions

1. Run the consolidation script:

```bash
python3 ~/.claude/scripts/consolidate-memory.py
```

2. Report the output summary to the user (lines before/after, duplicates removed, topic files created).

3. If the user wants to review changes, show a diff:

```bash
diff ~/.claude/projects/-home-george/memory/MEMORY.md.bak ~/.claude/projects/-home-george/memory/MEMORY.md
```

## What It Does

- Reads MEMORY.md and parses sections by `##` headers
- Extracts individual bullet entries
- Detects duplicates using exact substring matching and Jaccard word similarity (>0.6 threshold)
- Removes redundant entries, keeping the most detailed version
- Splits large topics (>20 lines) into separate topic files in the memory directory
- Keeps a summary with link in MEMORY.md for split topics
- Always creates a `.bak` backup before modifying
- Idempotent: running twice produces the same result
- Adds a "Last consolidated" timestamp

## Periodic Consolidation (Cron)

To run consolidation automatically (e.g., weekly), add a cron entry:

```bash
# Edit crontab
crontab -e

# Add this line for weekly consolidation (Sunday at 3am):
0 3 * * 0 /usr/bin/python3 ~/.claude/scripts/consolidate-memory.py >> ~/.claude/logs/consolidation.log 2>&1
```

Make sure the logs directory exists:
```bash
mkdir -p ~/.claude/logs
```
