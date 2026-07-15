---
name: github-main-merge
description: >
  Merge the current branch into main and push it to origin, with no tag created.
  Invoked when user calls `/github-main-merge`.
  Refuses to run if the working tree has uncommitted changes.
  On success, returns to the branch that was current before the skill ran.
  Unlike `/github-release`, this skill never creates a git tag.
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git checkout:*), Bash(git merge:*), Bash(git fetch:*), Bash(git push:*), Bash(git remote:*), Bash(git show-ref:*)
user-invocable: true
---

## Context

- Current branch: !`git branch --show-current`
- Working tree status: !`git status -sb`
- main branch exists locally: !`git show-ref --verify --quiet refs/heads/main && echo "yes" || echo "no"`
- Origin remote: !`git remote get-url origin 2>/dev/null || echo "(no origin)"`

## Task

Merge the current branch into `main` and push `main` to `origin`. Do not create any git tag. Return to the original branch after a successful run.

### Verify Git Repository

Verify the current directory is a git repository:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

If it fails (non-zero exit code), display and exit:
```
Error: Not a git repository.
```

### Verify Clean Working Tree

Check for uncommitted changes:

```bash
git status --porcelain
```

If the output is non-empty, display and exit:
```
Error: Uncommitted changes present. Commit or stash them before running /github-main-merge.
```

### Record Source Branch

Record the current branch name:

```bash
source_branch=$(git branch --show-current)
```

### Verify Origin Remote (only needed if main does not exist locally)

If `main` does not exist locally (see next step), first verify `origin` is configured:

```bash
git remote get-url origin 2>/dev/null
```

If it fails (non-zero exit code), display and exit:
```
Error: Remote 'origin' is not configured.
```

### Ensure/Checkout main Branch

Check if `main` exists locally:

- **`main` does NOT exist locally:** `git fetch origin main && git checkout -b main origin/main`
- **`main` exists and current branch IS main:** Skip checkout
- **`main` exists and current branch is NOT main:** `git checkout main`

### Merge or Determine Nothing-to-Push

**If `source_branch` was `main`** (no other branch to merge):

```bash
git fetch origin main --quiet 2>/dev/null
ahead=$(git rev-list origin/main..main --count 2>/dev/null || echo 0)
```

- If `ahead` is `0`, display and exit (do not push):
  ```
  main has nothing to merge and no local commits ahead of origin/main.
  ```
- If `ahead` is greater than `0`, proceed directly to "Push".

**If `source_branch` was NOT `main`:**
- Execute: `git merge "${source_branch}"`
- On conflict (exit code non-zero):
  - Execute: `git merge --abort`
  - Display error:
    ```
    Error: Merge conflict occurred while merging to main.
    To resolve manually:
      git merge --abort
    Then resolve conflicts and retry: /github-main-merge
    ```
  - Exit without pushing
- On success: Proceed to "Push"

### Push

```bash
git push origin main
```

**On push failure:**
- Display error with git's error message:
  ```
  Error: Failed to push to remote.
  <git error message here>
  ```
- **Do not** retry with `git push --force` or `git push --force-with-lease`
- Exit

**On push success:**
- If `source_branch` is not `main`, check it back out: `git checkout "${source_branch}"`
- Display completion message:
  ```
  ✓ Merge to main complete
    Merged from: <source_branch>
    Branch: main
    Remote: origin
    Returned to: <source_branch>
  ```
  (Omit the "Returned to" line if `source_branch` was `main`.)
