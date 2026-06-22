---
name: github-sync
description: >
  Perform a git pull followed by git push synchronization operation.
  Invoked when user calls `/github-sync` or `/github-sync ff`.
  Default is `--rebase` for pull; if `ff` is specified, use `--ff-only`.
  If pull fails, do not execute push.
allowed-tools: Bash(git pull:*), Bash(git push:*), Bash(git branch:*), Bash(git status:*), Bash(git remote:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- Current branch: !`git branch --show-current`
- Remote configuration: !`git remote -v`
- Current status: !`git status -sb`

## Task

Pull remote changes, then push local commits.

### Execute Pull

Check argument `$ARGUMENTS`:
- `ff` is present -> `git pull --ff-only`
- No argument (or argument other than `ff`) -> `git pull --rebase`

### Handle Pull Result

**If pull succeeds**: proceed to execute `git push`.

**If pull fails** (conflict, non-fast-forward rejection, etc.):
- **Do not** execute `git push`
- Report the error to the user
- If conflict occurred: suggest `git rebase --abort` or manual conflict resolution
- If `--ff-only` failed: suggest using `--rebase` or manual merge

### Push Behavior

After successful pull, push behavior is the same as `/github-push`:
- Upstream configured -> `git push`
- Upstream not configured -> `git push --set-upstream origin <current-branch>`
- Do not force-push
