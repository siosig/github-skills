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
```

### Description

Creates a single Git commit from current changes. By default, stages only tracked file changes (`git add -u`). Passing `all` also stages untracked files (`git add -A`).

### Options

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `all` | optional keyword | — | Include untracked files in the commit (`git add -A`) |

### Behavior

1. Inspect `$ARGUMENTS` to determine staging strategy:
   - If `all` is present → `git add -A`
   - Otherwise → `git add -u`
2. If no changes exist after staging, report "nothing to commit" and exit without creating a commit.
3. Analyze the diff (`git diff HEAD`) and recent commit history (`git log --oneline -10`) to compose a commit message.
4. Execute `git add` and `git commit` in a single step.

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

### Error Handling

| Condition | Behavior |
|-----------|----------|
| No staged changes | Report "nothing to commit", exit without creating commit |
| `git commit` fails | Surface git error message to user |

---

## `/github-push`

### Synopsis

```
/github-push [--private]
```

### Description

Pushes the current branch to its remote upstream. If no `origin` remote is configured, automatically creates a GitHub repository named after the current directory and sets it as origin before pushing.

### Options

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `--private` | optional flag | — | When creating a new repository, create it as private (default: public) |

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
```

### Description

Pulls remote changes, then pushes local commits. Designed to synchronize the current branch with its remote counterpart. Push is only executed when pull succeeds.

### Options

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `ff` | optional keyword | — | Use `--ff-only` instead of `--rebase` for pull |

### Behavior

1. **Pull**:
   - `ff` present → `git pull --ff-only`
   - Otherwise → `git pull --rebase`
2. **If pull succeeds**: Execute push (same logic as `/github-push` when origin exists):
   - Upstream configured → `git push`
   - Upstream not configured → `git push --set-upstream origin <branch>`
3. **If pull fails**: Do **not** push. Report the error and provide recovery guidance:
   - Conflict during rebase → suggest `git rebase --abort` or manual conflict resolution
   - `--ff-only` rejected → suggest using `--rebase` or manual merge
4. **Never force-push**.

### Error Handling

| Condition | Behavior |
|-----------|----------|
| Pull conflict | Report conflict, suggest `git rebase --abort` |
| `--ff-only` rejected | Suggest `git pull --rebase` |
| Push fails | Surface git error |

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
