---
name: github-sync
description: >
  Perform a git pull followed by git push synchronization operation.
  Invoked when user calls `/github-sync`, `/github-sync ff`, or `/github-sync <submodule> [ff]`.
  Default is `--rebase` for pull; if `ff` is specified, use `--ff-only`.
  Passing a submodule path synchronizes that submodule instead of the current repository.
  If pull fails, do not execute push.
allowed-tools: Bash(git pull:*), Bash(git push:*), Bash(git branch:*), Bash(git status:*), Bash(git remote:*), Bash(git submodule:*), Bash(git -C:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- Current branch: !`git branch --show-current`
- Remote configuration: !`git remote -v`
- Current status: !`git status -sb`
- Submodules: !`git submodule status 2>/dev/null || echo "(no submodules)"`

## Task

Pull remote changes, then push local commits — either in the current repository or in a submodule, depending on `$ARGUMENTS`.

### Parse Arguments

Split `$ARGUMENTS` into whitespace-separated tokens:

| Arguments | Mode | Repository | Pull |
|-----------|------|------------|------|
| (none) | repository | current | `git pull --rebase` |
| `ff` | repository | current | `git pull --ff-only` |
| `<submodule>` | submodule | `<submodule>` | `git pull --rebase` |
| `<submodule> ff` | submodule | `<submodule>` | `git pull --ff-only` |

The literal keyword `ff` as the **first** token always means repository mode. Any other first token is treated as a submodule path (strip a trailing `/`).

### Repository Mode

**Execute pull** per the table above.

**If pull succeeds**: proceed to execute `git push`.

**If pull fails** (conflict, non-fast-forward rejection, etc.):
- **Do not** execute `git push`
- Report the error to the user
- If conflict occurred: suggest `git rebase --abort` or manual conflict resolution
- If `--ff-only` failed: suggest using `--rebase` or manual merge

**Push behavior** is the same as `/github-push`:
- Upstream configured -> `git push`
- Upstream not configured -> `git push --set-upstream origin <current-branch>`
- Do not force-push

### Submodule Mode

Throughout this section, `<sub>` is the submodule path from the arguments.

**1. Validate the submodule**

```bash
git submodule status -- "<sub>"
```

If it exits non-zero or prints nothing, display and exit without syncing:
```
Error: '<sub>' is not a git submodule of this repository.
```

**2. Verify the submodule is on a branch**

```bash
git -C "<sub>" branch --show-current
```

If it prints nothing, the submodule is in detached HEAD state. Pull and push have no branch to work with, so display and exit **without** pulling or pushing:
```
Error: '<sub>' is in detached HEAD state.
Check out a branch inside the submodule first:
  git -C <sub> checkout <branch>
```

**3. Verify the submodule has an origin remote**

```bash
git -C "<sub>" remote get-url origin
```

If it fails (non-zero exit code), display and exit:
```
Error: Submodule '<sub>' has no 'origin' remote configured.
```

Never create a GitHub repository for a submodule — unlike `/github-push`, this skill does not auto-create remotes in submodule mode.

**4. Pull inside the submodule**

Use `git -C "<sub>"` for every git invocation. Never `cd`.

- `git -C "<sub>" pull --rebase` (or `--ff-only` when `ff` was passed)

**If pull fails**: do **not** push. Report the error and the same recovery guidance as repository mode, with `git -C "<sub>"` prefixed commands (e.g. `git -C <sub> rebase --abort`).

**5. Push inside the submodule**

- Upstream configured -> `git -C "<sub>" push`
- Upstream not configured -> `git -C "<sub>" push --set-upstream origin <submodule-branch>`
- Do not force-push

**6. Do not touch the parent repository**

Do not run `git add "<sub>"` and do not create a commit in the parent.

If the submodule's HEAD moved (the pull brought in new commits), the parent repository's gitlink for `<sub>` is now modified. Append to the report:
```
Note: the parent repository's gitlink for '<sub>' is now modified.
      Run /github-commit in the parent repository to record it.
```
