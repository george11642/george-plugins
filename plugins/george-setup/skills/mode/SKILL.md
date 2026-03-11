---
name: mode
description: "Switch behavior mode. Usage: /mode guided | autonomous | readonly. Updates ~/.claude/behavior.json."
---

# /mode — Behavior Mode Switch

When invoked as `/mode <preset>`, update `~/.claude/behavior.json` and confirm the change.

## Procedure

1. Read `~/.claude/behavior.json`
2. Apply the preset from the table below
3. Write the updated JSON back to `~/.claude/behavior.json`
4. Confirm with a one-line message: `Mode switched to <preset>: autonomy=<autonomy>`

## Presets

| Argument | autonomy | Toggles to set |
|----------|----------|----------------|
| `autonomous` / `fast` / `quick` / `ship` | autonomous | readonly = false |
| `guided` / `superpowers` | guided | readonly = false |
| `readonly` / `research` | guided | readonly = true |

## If no argument provided

Show current mode from behavior.json and list available presets.

## Axes Reference

| Axis | Values | Effect |
|------|--------|--------|
| **autonomy** | `autonomous` / `guided` | `autonomous`: never ask, proceed always. `guided`: checkpoint at milestones, confirm destructive actions. |

## Toggles Reference

| Toggle | Effect when ON |
|--------|---------------|
| `readonly` | Blocks Write/Edit/destructive Bash via `readonly-guard.js` hook |
