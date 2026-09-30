---
name: github-beta
description: >
  Push the current branch to develop and create a beta tag.
  Invoked when user calls `/github-beta` or `/github-beta X.Y.Z`.
  If develop branch does not exist, create it from the current branch.
  If X.Y.Z is specified, use it as the base version; otherwise, auto-increment the patch version of the latest production tag.
  Beta tags are numbered sequentially (beta.1, beta.2, ...) per base version.
allowed-tools: Bash(git tag:*), Bash(git branch:*), Bash(git checkout:*), Bash(git merge:*), Bash(git push:*), Bash(git rev-parse:*), Bash(grep:*), Bash(sort:*), Bash(head:*), Bash(tail:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- Current branch: !`git branch --show-current`
- Develop branch exists: !`git branch --list develop | grep -q . && echo "yes" || echo "no"`
- Latest production tag: !`git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1`
- All tags: !`git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+-beta'`

## Task

Push current branch to develop and create a beta release tag. Merge current branch into develop, then tag and push.

### Verify Git Repository

Verify the current directory is a git repository:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

If it fails (non-zero exit code), display and exit:
```
Error: Not a git repository.
```

### Resolve Version (base_version)

Determine the base version for the beta tag:

**If argument X.Y.Z is provided:**
- Validate format: Must match `^[0-9]+\.[0-9]+\.[0-9]+$` (three dot-separated integers)
- If validation fails, display error and exit:
  ```
  Error: Version format is invalid. Please specify in X.Y.Z format.
  ```
- Use `vX.Y.Z` as base_version

**If no argument is provided:**
- Get latest production tag: `git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1`
- If tag exists:
  - Extract patch version Z from `vX.Y.Z`
  - Increment Z by 1
  - Set base_version to `vX.Y.(Z+1)`
- If no tag exists:
  - Set base_version to `v0.0.1`

### Calculate Beta Tag (beta_tag)

Determine the beta tag number:

```bash
max_n=$(git tag --list "${base_version}-beta.*" | grep -oE '[0-9]+$' | sort -n | tail -1)
n=$((${max_n:-0} + 1))
beta_tag="${base_version}-beta.${n}"
```

### Ensure/Checkout develop Branch

Check if develop branch exists:

- **If develop does NOT exist:** `git checkout -b develop` (create from current branch)
- **If develop EXISTS and current branch IS develop:** Skip checkout, proceed to tagging
- **If develop EXISTS and current branch is NOT develop:** `git checkout develop`

### Merge Current Branch into develop

If current branch was not develop at start:
- Execute: `git merge <current_branch>`
- On conflict (exit code non-zero):
  - Execute: `git merge --abort`
  - Display error:
    ```
    Error: Merge conflict occurred while merging to develop.
    To resolve manually:
      git merge --abort
    Then resolve conflicts and retry: /github-beta
    ```
  - Exit without tagging or pushing
- On success: Proceed to tagging

### Create Tag and Push

```bash
git tag "${beta_tag}"
git push origin develop "${beta_tag}"
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
  ✓ Beta release complete
    Branch: develop
    Tag: <beta_tag>
    Remote: origin
  ```
