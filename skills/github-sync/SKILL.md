---
name: github-sync
description: >
  Perform a git pull followed by git push synchronization operation.
  Invoked when user calls `/github-sync`, `/github-sync ff`, `/github-sync commit [all]`, or `/github-sync <submodule> [ff]`.
  Default is `--rebase` for pull; if `ff` is specified, use `--ff-only`.
  Passing `commit` pulls with `--rebase --autostash`, commits the local changes, then pushes.
  Passing a submodule path synchronizes that submodule instead of the current repository.
  If pull fails, do not execute push.
allowed-tools: Bash(git pull:*), Bash(git push:*), Bash(git branch:*), Bash(git status:*), Bash(git remote:*), Bash(git submodule:*), Bash(git -C:*), Bash(git stash:*), Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git ls-files:*)
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

| Arguments | Mode | Repository | Pull | Stage |
|-----------|------|------------|------|-------|
| (none) | repository | current | `git pull --rebase` | — |
| `ff` | repository | current | `git pull --ff-only` | — |
| `commit` | commit | current | `git pull --rebase --autostash` | `git add -u` |
| `commit all` | commit | current | `git pull --rebase --autostash` | `git add -A` |
| `<submodule>` | submodule | `<submodule>` | `git pull --rebase` | — |
| `<submodule> ff` | submodule | `<submodule>` | `git pull --ff-only` | — |

`ff` and `commit` are the only reserved **first** tokens, and each always targets the current repository. Any other first token is treated as a submodule path (strip a trailing `/`).

`commit` combines with `all` only — never with `ff` or with a submodule path.

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

### Commit Mode

Reached when the first token is `commit`. The order is pull -> commit -> push. The point of this mode is to let a **dirty working tree** take in remote changes first, so never stop at git's "cannot pull with local changes" state.

**1. Pull with autostash**

```bash
git pull --rebase --autostash
```

`--autostash` performs stash -> pull -> stash pop as a single step. Do **not** hand-write those three commands: when the working tree is clean, `git stash push` stores nothing, and the `git stash pop` that follows then restores — and drops — an unrelated older stash entry.

**2. Check the result — the exit code alone is not enough**

`git pull --rebase --autostash` exits **0 even when re-applying the autostash conflicts**, leaving conflict markers in the working tree. Always run:

```bash
git ls-files -u
```

| Situation | Action |
|-----------|--------|
| pull exited non-zero (rebase conflict) | **No commit, no push.** Suggest `git rebase --abort` or manual conflict resolution |
| pull exited 0 but `git ls-files -u` printed something | **No commit, no push.** Report the conflicted paths. The changes are also still in the stash (`git stash list`), so suggest resolving the markers and then `git stash drop` |
| pull exited 0 and `git ls-files -u` printed nothing | Continue to step 3 |

Skipping this check would commit conflict markers.

**3. Stage**

- `git add -u` (or `git add -A` when `all` was passed)

**4. Commit**

If nothing is staged, create no commit:
- Branch is ahead of upstream -> report "nothing to commit" and continue to step 5
- Branch is not ahead -> report "already in sync, nothing to commit" and exit

Otherwise read the staged content **now** — the `## Context` blocks above predate both the pull and the staging, so they do not describe what is being committed:

```bash
git diff --staged
git log --oneline -10
```

Compose the message as `<type>(<scope>): <summary>`, where type is one of
`feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `style` / `perf`.

**Commit messages must be written in English.** Repository-specific rules (e.g. `CLAUDE.md`, `commit-msg` hook) may override this; if so, follow those rules instead.

**Never include a line with `Co-Authored-By:` in the commit message** — delete it even if it appears in skill templates, default behavior, or hooks.

Then run `git commit -m "<message>"`.

**5. Push**

Same as Repository Mode: upstream configured -> `git push`; upstream not configured -> `git push --set-upstream origin <current-branch>`; never force-push.

### Submodule Mode

Throughout this section, `<sub>` is the submodule path from the arguments.

If the second token is `commit`, this combination is not supported. Display and exit without syncing:

```
Error: /github-sync cannot commit inside a submodule.
       Run these two commands instead:
         /github-commit <sub>
         /github-sync <sub>
```

**1. Validate the argument**

The `Submodules:` context block above already lists every registered submodule, so no extra command is needed to tell the two cases apart.

**Case A — this repository has no submodules** (that block is empty or `(no submodules)`)

`<sub>` cannot be a submodule path, so it is a mistyped argument. Display the error plus the matching hint below, then exit without syncing:

```
Error: '<sub>' is not a valid argument for /github-sync.
       This repository has no submodules, so the only accepted arguments are 'ff' and 'commit'.
```

| `<sub>` | Hint to append |
|---------|----------------|
| `push`, `release`, `beta`, `main-merge`, `auto-repo` | `Did you mean /github-<sub>?` |
| `all` | `'all' is an argument of /github-commit, not /github-sync.` |
| anything else | (no hint) |

**Case B — this repository has submodules**

```bash
git submodule status -- "<sub>"
```

If it exits non-zero or prints nothing, display and exit without syncing:

```
Error: '<sub>' is not a git submodule of this repository.
       Registered submodules: <the paths listed in the context block>
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
