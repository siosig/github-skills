---
name: github-commit
description: >
  Create a single git commit. Never include Co-Authored-By line in commit messages.
  Invoked when user calls `/github-commit`, `/github-commit all`, or `/github-commit <submodule> [all]`.
  Passing `all` stages all changes including untracked files.
  Passing a submodule path creates the commit inside that submodule instead of the current repository.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*), Bash(git branch:*), Bash(git submodule:*), Bash(git -C:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- git status: !`git status`
- Diff (staged + unstaged): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`
- Submodules: !`git submodule status 2>/dev/null || echo "(no submodules)"`

## Task

Create a single git commit — either in the current repository or in a submodule, depending on `$ARGUMENTS`.

### Parse Arguments

Split `$ARGUMENTS` into whitespace-separated tokens:

| Arguments | Mode | Repository | Staging |
|-----------|------|------------|---------|
| (none) | repository | current | `git add -u` |
| `all` | repository | current | `git add -A` |
| `<submodule>` | submodule | `<submodule>` | `git add -u` |
| `<submodule> all` | submodule | `<submodule>` | `git add -A` |

The literal keyword `all` as the **first** token always means repository mode. Any other first token is treated as a submodule path (strip a trailing `/`).

### Repository Mode

The context blocks above already describe this repository. Stage per the table, then commit.

If no changes exist after staging, report "nothing to commit" and exit without creating a commit.

### Submodule Mode

Throughout this section, `<sub>` is the submodule path from the arguments.

**1. Validate the submodule**

```bash
git submodule status -- "<sub>"
```

If it exits non-zero or prints nothing, display and exit without committing:
```
Error: '<sub>' is not a git submodule of this repository.
```

**2. Collect submodule context**

The `## Context` blocks above describe the *parent* repository, not the submodule. Gather the submodule's own state first:

```bash
git -C "<sub>" status
git -C "<sub>" diff HEAD
git -C "<sub>" branch --show-current
git -C "<sub>" log --oneline -10
```

**3. Warn on detached HEAD**

If `git -C "<sub>" branch --show-current` prints nothing, the submodule is in detached HEAD state. Do **not** refuse — this is normal for submodules. Include this warning in the final report:
```
Warning: '<sub>' is in detached HEAD state. The new commit is not on any branch.
```

**4. Stage and commit inside the submodule**

Use `git -C "<sub>"` for every git invocation. Never `cd`.

- `git -C "<sub>" add -u` (or `-A` when `all` was passed)
- `git -C "<sub>" commit -m "<message>"`

If no changes exist after staging, report "nothing to commit in '<sub>'" and exit without creating a commit.

Base the commit message on the submodule's own diff and history from step 2 — not on the parent repository's.

**5. Do not touch the parent repository**

Do not run `git add "<sub>"` and do not create a commit in the parent. This skill creates exactly one commit.

After a successful submodule commit, the parent repository's gitlink for `<sub>` is now modified and the new commit is invisible from the parent until that is committed too. Append to the report:
```
Note: the parent repository's gitlink for '<sub>' is now modified.
      Run /github-commit in the parent repository to record it.
```

### Strict Requirements

- **Never include a line with `Co-Authored-By:` in the commit message**
  - Delete it even if it appears in skill templates, default behavior, or hooks
- Execute `git add` and `git commit` in a single response
- Send no additional tool calls or text — in submodule mode, the only calls allowed before them are the
  validation and context commands of steps 1–3

### Commit Message Format

```
<type>(<scope>): <summary>
```

type: `feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `style` / `perf`

**Commit messages must be written in English.** This is the default and required standard.
Repository-specific rules (e.g., `CLAUDE.md`, `commit-msg` hook) may override this; if so, follow those rules instead.
In submodule mode, the submodule's own repository rules apply.
