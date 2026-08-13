---
name: github-main-merge
description: >
  Merge the current branch into the repository's default integration branch
  (`main` if it exists, otherwise `master`) and push it to origin, with no tag created.
  Invoked when user calls `/github-main-merge`.
  Refuses to run if the working tree has uncommitted changes.
  On success, returns to the branch that was current before the skill ran.
  Unlike `/github-release`, this skill never creates a git tag.
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git checkout:*), Bash(git merge:*), Bash(git fetch:*), Bash(git push:*), Bash(git remote:*), Bash(git show-ref:*), Bash(git ls-remote:*)
user-invocable: true
---

## Context

- Current branch: !`git branch --show-current`
- Working tree status: !`git status -sb`
- Local branches: !`git branch --format='%(refname:short)' | tr '\n' ' '`
- main branch exists locally: !`git show-ref --verify --quiet refs/heads/main && echo "yes" || echo "no"`
- master branch exists locally: !`git show-ref --verify --quiet refs/heads/master && echo "yes" || echo "no"`
- Origin remote: !`git remote get-url origin 2>/dev/null || echo "(no origin)"`

## Task

Merge the current branch into the repository's integration branch — `main` if it exists, otherwise `master` — and push that branch to `origin`. Do not create any git tag. Return to the original branch after a successful run.

Throughout this document, `<target>` refers to the resolved integration branch name (`main` or `master`).

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

### Resolve Target Branch

Determine `<target>` in this order, stopping at the first match. `main` always wins over `master` when both are present.

1. Local `main` exists — `git show-ref --verify --quiet refs/heads/main` → `target=main` (already local)
2. Local `master` exists — `git show-ref --verify --quiet refs/heads/master` → `target=master` (already local)
3. Remote `origin/main` exists — `git ls-remote --exit-code --heads origin main` → `target=main` (needs local creation)
4. Remote `origin/master` exists — `git ls-remote --exit-code --heads origin master` → `target=master` (needs local creation)

Steps 3 and 4 require `origin`. Before running them, verify it is configured:

```bash
git remote get-url origin 2>/dev/null
```

If it fails (non-zero exit code), display and exit:
```
Error: Remote 'origin' is not configured.
```

If none of the four checks match, display and exit:
```
Error: Neither 'main' nor 'master' branch was found locally or on origin.
```

### Ensure/Checkout Target Branch

- **`<target>` does NOT exist locally** (resolved via `origin`): `git fetch origin <target> && git checkout -b <target> origin/<target>`
- **`<target>` exists and current branch IS `<target>`:** Skip checkout
- **`<target>` exists and current branch is NOT `<target>`:** `git checkout <target>`

### Merge or Determine Nothing-to-Push

**If `source_branch` was `<target>`** (no other branch to merge):

```bash
git fetch origin <target> --quiet 2>/dev/null
ahead=$(git rev-list origin/<target>..<target> --count 2>/dev/null || echo 0)
```

- If `ahead` is `0`, display and exit (do not push):
  ```
  <target> has nothing to merge and no local commits ahead of origin/<target>.
  ```
- If `ahead` is greater than `0`, proceed directly to "Push".

**If `source_branch` was NOT `<target>`:**
- Execute: `git merge "${source_branch}"`
- On conflict (exit code non-zero):
  - Execute: `git merge --abort`
  - Display error:
    ```
    Error: Merge conflict occurred while merging to <target>.
    To resolve manually:
      git merge --abort
    Then resolve conflicts and retry: /github-main-merge
    ```
  - Exit without pushing
- On success: Proceed to "Push"

### Push

```bash
git push origin <target>
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
- If `source_branch` is not `<target>`, check it back out: `git checkout "${source_branch}"`
- Display completion message:
  ```
  ✓ Merge to <target> complete
    Merged from: <source_branch>
    Branch: <target>
    Remote: origin
    Returned to: <source_branch>
  ```
  (Omit the "Returned to" line if `source_branch` was `<target>`.)
