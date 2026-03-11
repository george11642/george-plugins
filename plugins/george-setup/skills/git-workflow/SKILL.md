---
name: git-workflow
description: "Use when committing code, creating PRs, managing branches, or resolving git conflicts. Triggers on git commit, git push, git status, git diff, git stash, git revert, cherry-pick, merge conflict, pull request, PR, create PR, squash merge, conventional commit, branch, feature branch, gh pr, git log, rebase, upstream, origin, stage files, git add."
---

# Git Workflow

## Commit Convention
```
type(scope): subject (max 72 chars)

- bullet body for non-trivial changes

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `perf`
Scopes: use project-appropriate scopes (check project's CLAUDE.md)

## Branch Strategy
- `main` — production, always deployable
- `feat/description` — feature branches
- `fix/description` — bug fix branches

## Commands
| Task | Command |
|------|---------|
| Status | `git status` |
| Stage specific files | `git add file1 file2` (never `git add .` for safety) |
| Commit | `git commit -m "type(scope): message"` |
| Push | `git push -u origin branch-name` |
| Create PR | `gh pr create --title "..." --body "..."` |
| View PR | `gh pr view [number]` |
| Merge PR | `gh pr merge [number] --squash` |

## Safety
- Never force-push to main
- Never `git add .` (stage specific files)
- Never skip hooks (`--no-verify`)
- Always `git stash` before risky operations
- Resolve conflicts manually, never `--ours`/`--theirs` blindly
