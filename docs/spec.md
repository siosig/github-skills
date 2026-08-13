# github-skills — Behavioral Specification

> Japanese version: [spec.ja.md](spec.ja.md)

**Plugin**: `github-skills`  
**Version**: 1.0.0  
**Last Updated**: 2026-06-22

---

## Overview

This document describes the complete behavioral specification of all skills provided by the `github-skills` Claude Code plugin. Each skill is invoked by the user via a slash command (e.g., `/github-commit`) and executed by Claude Code in the current working directory.

---

## `/github-commit`

### Synopsis

```
/github-commit [all]
/github-commit <submodule> [all]
```

Optional arguments:
- `all` — Include untracked files in the commit
- `<submodule>` — Path of a submodule; the commit is created inside that submodule

### Description

Creates a single Git commit from current changes. By default, stages only tracked file changes (`git add -u`). Passing `all` also stages untracked files (`git add -A`).

When the first argument is anything other than `all`, it is treated as a submodule path and the commit is created inside that submodule (`git -C <submodule>`) instead of the current repository.

### Options

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `all` | optional keyword | — | Include untracked files in the commit (`git add -A`) |
| `<submodule>` | optional path (1st token) | — | Commit inside this submodule; may be followed by `all` |

### Behavior

1. Split `$ARGUMENTS` into whitespace-separated tokens and resolve the mode:

   | Arguments | Mode | Target repository | Staging |
   |-----------|------|-------------------|---------|
   | (none) | repository | current | `git add -u` |
   | `all` | repository | current | `git add -A` |
   | `<submodule>` | submodule | `<submodule>` | `git add -u` |
   | `<submodule> all` | submodule | `<submodule>` | `git add -A` |

   A first token of `all` always means repository mode. Any other first token is a submodule path (trailing `/` stripped).

2. **Repository mode**
   1. Stage per the table above.
   2. If no changes exist after staging, report "nothing to commit" and exit without creating a commit.
   3. Analyze the diff (`git diff HEAD`) and recent commit history (`git log --oneline -10`) to compose a commit message.
   4. Execute `git add` and `git commit` in a single step.

3. **Submodule mode**
   1. Validate the path with `git submodule status -- <submodule>`. If it exits non-zero or prints nothing, report an error and exit.
   2. Collect the submodule's own state (`git -C <submodule>` for `status`, `diff HEAD`, `branch --show-current`, `log --oneline -10`) — the parent repository's context does not describe it.
   3. If the submodule is in detached HEAD state, warn but proceed.
   4. Stage and commit inside the submodule with `git -C <submodule>`; never `cd`.
   5. If no changes exist after staging, report "nothing to commit in `<submodule>`" and exit without creating a commit.
   6. Do not stage or commit the parent repository's gitlink. Report that the gitlink is now modified and that `/github-commit` must be run in the parent repository to record it.

### Commit Message Format

```
<type>(<scope>): <summary>
```

| Field | Values |
|-------|--------|
| `type` | `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf` |
| `scope` | Derived from changed file paths (optional) |
| `summary` | Concise description in English |

Commit messages are written in **English by default**. Repository-specific rules (e.g., `CLAUDE.md`, `commit-msg` hook) take precedence.

### Constraints

- **Never** include `Co-Authored-By:` in commit messages, regardless of any template or default behavior.
- Does not push after committing.
- Creates exactly one commit. In submodule mode, the parent repository is left untouched.

### Error Handling

| Condition | Behavior |
|-----------|----------|
| No staged changes | Report "nothing to commit", exit without creating commit |
| `git commit` fails | Surface git error message to user |
| First argument is not `all` and not a registered submodule | Report `Error: '<submodule>' is not a git submodule of this repository.`, exit without creating commit |
| Submodule is in detached HEAD | Warn, but create the commit |

---

## `/github-push`

### Synopsis

```
/github-push [private]
```

Optional argument:
- `private` — Create a private repository (default: public)

### Description

Pushes the current branch to its remote upstream. If no `origin` remote is configured, automatically creates a GitHub repository named after the current directory and sets it as origin before pushing.

### Behavior

#### Pre-flight Check

Verify the current directory is a Git repository. If not, report an error and exit.

#### Origin Exists

If `git remote get-url origin` succeeds:

| Condition | Action |
|-----------|--------|
| Upstream branch configured | `git push` |
| Upstream branch not configured | `git push --set-upstream origin <branch>` |
| Non-fast-forward rejected | Report error; prompt user to `git pull`. **Never force-push.** |
| Other error | Surface git error message to user |

#### Origin Missing — Auto-Create Flow

If no `origin` remote is configured:

1. **Auth check**: Run `gh auth status`. If unauthenticated, report error with `gh auth login` instruction and exit.
2. **Determine visibility**: `--private` present → private; otherwise → public.
3. **Sanitize repository name** from the current directory name:
   - Replace spaces with `-`
   - Remove characters not in `[a-zA-Z0-9._-]`
   - Strip leading/trailing `.`, `-`, `_`
   - Truncate to 100 characters
   - If the result is empty, report an error and exit.
   - Always display the sanitized name to the user.
4. **Create repository**: `gh repo create <name> --public|--private --json url -q '.url'`
   - If a repository with the same name already exists on github.com, report an error and exit. Do **not** set origin automatically.
5. **Set remote**: `git remote add origin <url>`
6. **Push**: `git push --set-upstream origin <branch>`
   - If push fails: report error with manual retry instructions. **Do not delete the created repository.**

### Error Messages

| Condition | Message |
|-----------|---------|
| Not a git repository | `エラー: git リポジトリではありません。` |
| gh not authenticated | `エラー: GitHub CLI が認証されていません。\n実行してください: gh auth login` |
| Cannot generate repo name | `エラー: フォルダ名からリポジトリ名を生成できません。` |
| Same-name repo exists | `エラー: github.com に同名のリポジトリ (<name>) が既に存在します。\n手動で origin を設定してください: git remote add origin <url>` |
| Push failed (after create) | `⚠ リポジトリの作成と origin の設定は完了しましたが、プッシュが失敗しました。\n  origin: <url>\n  手動で再試行してください: git push --set-upstream origin <branch>` |

### Required Tools

`git`, `gh`, `basename`, `tr`, `sed`, `cut`

---

## `/github-sync`

### Synopsis

```
/github-sync [ff]
/github-sync <submodule> [ff]
```

Optional arguments:
- `ff` — Use `--ff-only` instead of `--rebase` for pull
- `<submodule>` — Path of a submodule; the synchronization runs inside that submodule

### Description

Pulls remote changes, then pushes local commits. Designed to synchronize the current branch with its remote counterpart. Push is only executed when pull succeeds.

When the first argument is anything other than `ff`, it is treated as a submodule path and the synchronization runs inside that submodule (`git -C <submodule>`) instead of the current repository.

### Options

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `ff` | optional keyword | — | Use `git pull --ff-only` instead of `git pull --rebase` |
| `<submodule>` | optional path (1st token) | — | Synchronize this submodule; may be followed by `ff` |

### Behavior

1. Split `$ARGUMENTS` into whitespace-separated tokens and resolve the mode:

   | Arguments | Mode | Target repository | Pull |
   |-----------|------|-------------------|------|
   | (none) | repository | current | `git pull --rebase` |
   | `ff` | repository | current | `git pull --ff-only` |
   | `<submodule>` | submodule | `<submodule>` | `git pull --rebase` |
   | `<submodule> ff` | submodule | `<submodule>` | `git pull --ff-only` |

   A first token of `ff` always means repository mode. Any other first token is a submodule path (trailing `/` stripped).

2. **Repository mode**
   1. **Pull** per the table above.
   2. **If pull succeeds**: Execute push (same logic as `/github-push` when origin exists):
      - Upstream configured → `git push`
      - Upstream not configured → `git push --set-upstream origin <branch>`
   3. **If pull fails**: Do **not** push. Report the error and provide recovery guidance:
      - Conflict during rebase → suggest `git rebase --abort` or manual conflict resolution
      - `--ff-only` rejected → suggest using `--rebase` or manual merge
   4. **Never force-push**.

3. **Submodule mode**
   1. Validate the path with `git submodule status -- <submodule>`. If it exits non-zero or prints nothing, report an error and exit.
   2. If the submodule is in detached HEAD state (`git -C <submodule> branch --show-current` prints nothing), report an error and exit without pulling or pushing — there is no branch to pull into or push.
   3. If the submodule has no `origin` remote, report an error and exit. Unlike `/github-push`, no GitHub repository is ever auto-created in submodule mode.
   4. Pull and push inside the submodule with `git -C <submodule>`; never `cd`. Pull failure suppresses push exactly as in repository mode.
   5. Do not stage or commit the parent repository's gitlink. If the submodule's HEAD moved, report that the gitlink is now modified and that `/github-commit` must be run in the parent repository to record it.

### Error Handling

| Condition | Behavior |
|-----------|----------|
| Pull conflict | Report conflict, suggest `git rebase --abort` |
| `--ff-only` rejected | Suggest `git pull --rebase` |
| Push fails | Surface git error |
| First argument is not `ff` and not a registered submodule | Report `Error: '<submodule>' is not a git submodule of this repository.`, exit without syncing |
| Submodule is in detached HEAD | Report error, exit without pulling or pushing |
| Submodule has no `origin` remote | Report error, exit without pulling or pushing |

---

## `/github-auto-repo`

### Synopsis

```
/github-auto-repo [private]
```

Optional argument:
- `private` — Create a private repository (default: public)

### Description

Creates a GitHub repository matching the name of the current directory. The repository name is derived from the directory name with automatic sanitization. Supports both public (default) and private repositories via optional flag.

### Behavior

#### Pre-flight Checks

1. **Git repository validation**: Verify `git rev-parse --is-inside-work-tree` succeeds. If not, report error and exit with code 2.
2. **GitHub authentication**: Run `gh auth status`. If auth fails, report error and exit with code 3.

#### Folder Name Processing

1. **Get directory name**: Extract from `basename $(pwd)`
2. **Sanitize**:
   - Replace spaces with hyphens
   - Remove characters not in `[a-zA-Z0-9_-]`
   - Convert to lowercase
   - Limit to 39 characters
3. **Fallback**: If sanitized name is empty, try parent directory name using same sanitization
4. **Validate**: If still empty after fallback, report error and exit with code 5

#### Repository Creation

1. **Check for duplicates**: Query `gh repo list --source` and grep for exact name match. If found, report error and exit with code 4.
2. **Determine visibility**: `--private` present → private; otherwise → public
3. **Create repository**:
   - Public: `gh repo create <name> --public --source=. --remote=origin`
   - Private: `gh repo create <name> --private --source=. --remote=origin`
   - If creation fails, report error and exit with code 7

#### Branch Management

1. **Ensure main branch**: Verify `main` branch exists (GitHub's default)
2. **Create develop branch**: `git checkout -b develop`
3. **Push both branches**: `git push origin main develop`
   - If push fails, report error and exit with code 7

#### Success Output

```
✓ Repository created successfully
  Name: <sanitized_name>
  Visibility: <public|private>
  Remote: origin
  URL: <github_url>
  Branches: main, develop
```

### Error Messages

| Exit Code | Condition | Message |
|-----------|-----------|---------|
| 2 | Not a git repository | `Error: Not a git repository.` |
| 3 | GitHub auth failed | `Error: GitHub authentication failed.` |
| 4 | Repository already exists | `Error: Repository '<name>' already exists on GitHub.` |
| 5 | Invalid repository name | `Error: Folder name cannot be converted to a valid repository name.` |
| 7 | Network or push error | `Error: Failed to create repository. Check your permissions or network.` |

### Required Tools

`git`, `gh`, `basename`, `grep`, `sed`, `tr`, `cut`

### Key Behaviors

- Automatically creates both `main` and `develop` branches
- Does not reuse or overwrite existing repositories
- Displays sanitized repository name for user confirmation
- Simple error messages without recovery instructions
- All operations are atomic (full success or full failure, no partial state)

---

## Planned Skills

The following skills are in the specification phase and not yet implemented:

| Command | Description |
|---------|-------------|
| `/github-beta [X.Y.Z]` | Merge current branch into `develop`, create `vX.Y.Z-beta.n` tag, and push |
| `/github-release [X.Y.Z]` | Merge current branch into `main`, create `vX.Y.Z` tag, and push |

See [specs/003-release-flow/spec.md](../specs/003-release-flow/spec.md) for the full specification.

---

## Common Constraints

These rules apply to all skills unless explicitly overridden:

- Skills operate on the current working directory
- Skills never force-push (`--force` or `--force-with-lease`)
- Skills surface underlying tool error messages rather than hiding them
- Skills report their progress clearly so the user understands each step
