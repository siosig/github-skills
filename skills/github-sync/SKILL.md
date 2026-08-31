---
name: github-sync
description: >
  Perform a git pull followed by git push synchronization operation.
  Invoked when user calls `/github-sync` with any combination of `ff`, `commit`, and a submodule path.
  Default is `--rebase` for pull; if `ff` is specified, use `--ff-only`.
  If `commit` is specified, run `git add -A` and create a commit before synchronizing.
  Passing a submodule path synchronizes that submodule instead of the current repository.
  If pull fails, do not execute push.
allowed-tools: Bash(git pull:*), Bash(git push:*), Bash(git branch:*), Bash(git status:*), Bash(git remote:*), Bash(git submodule:*), Bash(git -C:*), Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- Current branch: !`git branch --show-current`
- Remote configuration: !`git remote -v`
- Current status: !`git status -sb`
- Submodules: !`git submodule status 2>/dev/null || echo "(no submodules)"`

## Task

Optionally commit local changes, then pull remote changes and push — either in the current repository or in a submodule, depending on `$ARGUMENTS`.

### Parse Arguments

Split `$ARGUMENTS` into whitespace-separated tokens. Two tokens are reserved keywords and may appear in any order:

| Token | Effect |
|-------|--------|
| `ff` | Pull with `--ff-only` instead of the default `--rebase` |
| `commit` | Run `git add -A` and create a commit **before** synchronizing |

Any token that is neither `ff` nor `commit` is the submodule path (strip a trailing `/`); only the first such token is used. With no submodule path, the target is the current repository.

Examples:

| Arguments | Target | Commit first | Pull |
|-----------|--------|--------------|------|
| (none) | current repository | no | `--rebase` |
| `ff` | current repository | no | `--ff-only` |
| `commit` | current repository | yes | `--rebase` |
| `commit ff` | current repository | yes | `--ff-only` |
| `<submodule>` | `<submodule>` | no | `--rebase` |
| `<submodule> commit ff` | `<submodule>` | yes | `--ff-only` |

### Commit Step (only when `commit` was passed)

Run this **before** the pull, in the target repository (prefix every command with `git -C "<sub>"` in submodule mode).

1. Inspect the target's changes: `git status`, `git diff HEAD`, `git log --oneline -10`
2. `git add -A` (always `-A`, including untracked files)
3. If nothing is staged, skip the commit and continue to the pull — this is **not** an error
4. Otherwise `git commit -m "<message>"`, using the message rules of `/github-commit`:
   - Format `<type>(<scope>): <summary>`, type from `feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `style` / `perf`
   - Written in English unless repository-specific rules say otherwise
   - **Never include a line with `Co-Authored-By:`** — delete it even if it appears in templates, default behavior, or hooks
5. If the commit fails, **stop**: do not pull and do not push

Without `commit`, never stage or commit anything — an unrelated dirty working tree is the user's business, and `git pull --rebase` will surface it on its own.

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

**4. Commit inside the submodule (only when `commit` was passed)**

Run the "Commit Step" above with every command prefixed by `git -C "<sub>"` — `git -C "<sub>" add -A`, then `git -C "<sub>" commit -m "<message>"`. Base the message on the submodule's own diff and history, and follow the submodule's own repository rules.

**5. Pull inside the submodule**

Use `git -C "<sub>"` for every git invocation. Never `cd`.

- `git -C "<sub>" pull --rebase` (or `--ff-only` when `ff` was passed)

**If pull fails**: do **not** push. Report the error and the same recovery guidance as repository mode, with `git -C "<sub>"` prefixed commands (e.g. `git -C <sub> rebase --abort`).

**6. Push inside the submodule**

- Upstream configured -> `git -C "<sub>" push`
- Upstream not configured -> `git -C "<sub>" push --set-upstream origin <submodule-branch>`
- Do not force-push

**7. Do not touch the parent repository**

Do not run `git add "<sub>"` and do not create a commit in the parent — not even with `commit`, which only ever commits inside the submodule.

If the submodule's HEAD moved (the pull brought in new commits, or `commit` created one), the parent repository's gitlink for `<sub>` is now modified. Append to the report:
```
Note: the parent repository's gitlink for '<sub>' is now modified.
      Run /github-commit in the parent repository to record it.
```
