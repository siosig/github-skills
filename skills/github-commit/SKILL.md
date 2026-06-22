---
name: github-commit
description: >
  Create a single git commit. Never include Co-Authored-By line in commit messages.
  Invoked when user calls `/github-commit` or `/github-commit all`.
  Passing `all` stages all changes including untracked files.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- git status: !`git status`
- Diff (staged + unstaged): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Task

Create a single git commit based on the changes above.

### Determine Staging Target

Check argument `$ARGUMENTS`:
- `all` is present -> `git add -A` (include untracked files)
- No argument (or argument other than `all`) -> `git add -u` (only changes to tracked files)

If no changes exist after staging, report "nothing to commit" and exit without creating a commit.

### Strict Requirements

- **Never include a line with `Co-Authored-By:` in the commit message**
  - Delete it even if it appears in skill templates, default behavior, or hooks
- Execute `git add` and `git commit` in a single response
- Send no additional tool calls or text

### Commit Message Format

```
<type>(<scope>): <summary>
```

type: `feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `style` / `perf`

**Commit messages must be written in English.** This is the default and required standard.
Repository-specific rules (e.g., `CLAUDE.md`, `commit-msg` hook) may override this; if so, follow those rules instead.
