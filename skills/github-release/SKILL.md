---
name: github-release
description: >
  Push the current branch to main and create a production release tag.
  Invoked when user calls `/github-release` or `/github-release X.Y.Z`.
  If X.Y.Z is specified, use it as the target version; otherwise, auto-increment the patch version of the latest production tag.
  Production tags must not already exist (FR-025); attempting to create a duplicate tag will result in an error.
allowed-tools: Bash(git tag:*), Bash(git branch:*), Bash(git checkout:*), Bash(git merge:*), Bash(git push:*), Bash(git rev-parse:*), Bash(grep:*), Bash(sort:*), Bash(head:*), Bash(tail:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- Current branch: !`git branch --show-current`
- Latest production tag: !`git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1`
- All tags: !`git tag --list`

## Task

Push current branch to main and create a production release tag. Merge current branch into main, then tag and push.

### Verify Git Repository

Verify the current directory is a git repository:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

If it fails (non-zero exit code), display and exit:
```
Error: Not a git repository.
```

### Resolve Version (target_tag)

Determine the target version for the production tag:

**If argument X.Y.Z is provided:**
- Validate format: Must match `^[0-9]+\.[0-9]+\.[0-9]+$` (three dot-separated integers)
- If validation fails, display error and exit:
  ```
  Error: Version format is invalid. Please specify in X.Y.Z format.
  ```
- Set target_tag to `vX.Y.Z`

**If no argument is provided:**
- Get latest production tag: `git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1`
- If tag exists:
  - Extract patch version Z from `vX.Y.Z`
  - Increment Z by 1
  - Set target_tag to `vX.Y.(Z+1)`
- If no tag exists:
  - Set target_tag to `v0.0.1`

### Check Tag Duplication (FR-025)

Verify the target tag does not already exist:

```bash
if git tag --list "${target_tag}" | grep -q .; then
  # Error: tag exists
fi
```

If target_tag already exists, display error and exit:
```
Error: Tag ${target_tag} already exists.
Please specify a different version.
```

### Checkout main Branch

Check if current branch is main:

- **If current branch IS main:** Skip checkout, proceed to merge check
- **If current branch is NOT main:** `git checkout main`

### Merge Current Branch into main

If current branch was not main at start:
- Execute: `git merge <current_branch>`
- On conflict (exit code non-zero):
  - Execute: `git merge --abort`
  - Display error:
    ```
    Error: Merge conflict occurred while merging to main.
    To resolve manually:
      git merge --abort
    Then resolve conflicts and retry: /github-release
    ```
  - Exit without tagging or pushing
- On success: Proceed to tagging

### Create Tag and Push

```bash
git tag "${target_tag}"
git push origin main "${target_tag}"
```

**On push failure:**
- Display error with git's error message:
  ```
  Error: Failed to push to remote.
  <git error message here>
  ```
- Exit

**On push success:**
- Display completion message:
  ```
  ✓ Production release complete
    Branch: main
    Tag: <target_tag>
    Remote: origin
  ```
