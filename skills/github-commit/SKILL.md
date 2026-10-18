---
name: github-commit
description: >
  Create a single git commit. Never include Co-Authored-By line in commit messages.
  Invoked when user calls `/github-commit`, `/github-commit all`, or `/github-commit <submodule> [all]`.
  Passing `all` stages all changes including untracked files.
  Passing a submodule path creates the commit inside that submodule instead of the current repository.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*), Bash(git branch:*), Bash(git submodule:*), Bash(git -C:*), Bash(head:*), Bash(grep:*), Bash(sed -n:*)
model: haiku
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- git status: !`git status --short`
- Diff summary (staged + unstaged): !`git diff HEAD --stat`
- Diff body (lockfiles excluded, capped at 300 lines): !`git diff HEAD -- . ':(exclude)*.lock' ':(exclude)*-lock.*' ':(exclude)*lock.json' | head -n 300`
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

### Staging Scope

The Staging column above is the scope. Applies to both modes (in submodule mode, use the submodule's `status --short` from step 2 and prefix every git command with `-C "<sub>"`).

- **Never narrow it on your own** — no `git add -- <path>`, no leaving paths out because they look unrelated to the current work (e.g. `.mcp.json`, notes, docs).
- Stage a different scope **only when the user explicitly named one** (e.g. "commit only `src/`").
- **Before `git add`, screen every path it would stage** (`git status --short`: tracked changes, plus `??` lines with `all`). Flag a path that looks like:
  - a secret (`.env*`, `*.pem`, `*.key`, `id_rsa*`, credential/token files, or a diff adding a key, token, or password)
  - a browser profile or application cache directory
  - a large generated artifact (build output, `node_modules/`, archives, binaries, dumps)
  - anything else that belongs in `.gitignore`
- Nothing flagged → stage per the table and commit (Strict Requirements apply as written).
- Something flagged → **do not stage or commit yet. Never drop a path silently.** Show each flagged path with its reason, ask the user to choose per path, then stop and wait:
  1. Add it to `.gitignore` (untracked paths only), then stage per the table
  2. Exclude it from this commit: `git add -A -- . ':(exclude)<path>'` (`-u` instead of `-A` without `all`)
  3. Include it as is
- After the answer, stage per the choices and commit in a single response.

### Repository Mode

The context blocks above describe this repository: file list, per-file line counts, and the diff body (lockfiles excluded, capped at 300 lines). Screen per Staging Scope, stage per the table, then commit.

**Is the embedded diff complete?** It is truncated if it is exactly 300 lines long. Untracked files (relevant with `all`) never appear in it.

- Complete: write the message from it. No extra reads.
- Truncated, or untracked files matter: read selectively before `git add`/`git commit` (allowed ahead of them):
  - Pick files from the `--stat` that are not lockfiles or generated files, and read them in one call: `git diff HEAD -- <path> [<path>...]`. Read the diff of **at least one** such file; never write the message from file names alone.
  - Read the needed untracked files with the Read tool.
  - If the selected diff is still large, redirect it to a scratchpad file (`> <file> 2>&1`) and read only the relevant hunks with `grep` / `sed -n`.
- Never run a bare `git diff HEAD` over the whole tree.

If no changes exist after staging, report "nothing to commit" and exit without creating a commit.

### Submodule Mode

Throughout this section, `<sub>` is the submodule path from the arguments.

**1. Validate the argument**

The `Submodules:` context block above already lists every registered submodule, so no extra command is needed to tell the two cases apart.

**Case A — this repository has no submodules** (that block is empty or `(no submodules)`)

`<sub>` cannot be a submodule path, so it is a mistyped argument. Display the error plus the matching hint below, then exit without committing:

```
Error: '<sub>' is not a valid argument for /github-commit.
       This repository has no submodules, so the only accepted argument is 'all'.
```

| `<sub>` | Hint to append |
|---------|----------------|
| `sync`, `push`, `release`, `beta`, `main-merge`, `auto-repo` | `Did you mean /github-<sub>?` |
| `ff` | `'ff' is an argument of /github-sync, not /github-commit.` |
| anything else | (no hint) |

**Case B — this repository has submodules**

```bash
git submodule status -- "<sub>"
```

If it exits non-zero or prints nothing, display and exit without committing:

```
Error: '<sub>' is not a git submodule of this repository.
       Registered submodules: <the paths listed in the context block>
```

**2. Collect submodule context**

The `## Context` blocks above describe the *parent* repository, not the submodule. Gather the submodule's own state first:

```bash
git -C "<sub>" status --short
git -C "<sub>" diff HEAD --stat
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

Base the commit message on the submodule's own diff and history — not on the parent repository's. Read the needed file diffs selectively with `git -C "<sub>" diff HEAD -- <path>` (same rules as repository mode), before staging.

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
- Follow the Staging Scope section: never narrow the table's scope unless the user named one
- Execute `git add` and `git commit` in a single response
- Send no additional tool calls or text — the only calls allowed before them are the selective diff reads
  (`git diff HEAD -- <path>`, `grep` / `sed -n` on a scratchpad file holding that output, Read of untracked files) (and, in submodule mode, the validation and context commands of steps 1–3)
- Sole exception: when the Staging Scope screen flags a path, stop before `git add` and ask; stage and commit in a single response after the user answers

### Commit Message Format

```
<type>(<scope>): <summary>
```

type: `feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `style` / `perf`

**Commit messages must be written in English.** This is the default and required standard.
Repository-specific rules (e.g., `CLAUDE.md`, `commit-msg` hook) may override this; if so, follow those rules instead.
In submodule mode, the submodule's own repository rules apply.
