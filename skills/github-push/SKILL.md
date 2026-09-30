---
name: github-push
description: >
  Push the current branch to upstream via git push.
  Invoked when user calls `/github-push` or `/github-push private`.
  If origin is not configured, automatically create a GitHub repository named after the current folder and set it as origin before pushing.
  With `private` argument, create a private repository (default: public).
  If upstream is not configured, push with `--set-upstream origin <branch>`.
  Do not force-push on non-fast-forward rejection.
allowed-tools: Bash(git push:*), Bash(git branch:*), Bash(git remote:*), Bash(gh:*), Bash(basename:*), Bash(tr:*), Bash(sed:*), Bash(cut:*)
user-invocable: true
---

## Context

- Arguments: `$ARGUMENTS`
- Current branch: !`git branch --show-current`
- Origin configuration: !`git remote get-url origin 2>/dev/null || echo "(no origin)"`
- Upstream status: !`git status -sb`

## Task

Push the current branch to remote. If origin is not configured, automatically create a GitHub repository.

### Verify Git Repository

Verify the current directory is a git repository:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

If it fails (non-zero exit code), display and exit:
```
Error: Not a git repository.
```

### Check Origin Remote

Execute `git remote get-url origin 2>/dev/null`:

- **origin exists** -> proceed to "Execute Push" section
- **origin does not exist** -> proceed to "Auto-create Repository Flow" section

---

### Execute Push (when origin exists)

Check upstream branch configuration:

- Upstream configured -> `git push`
- Upstream not configured (first line of `git status -sb` does not contain `[origin/...]`) -> `git push --set-upstream origin <current-branch>`

#### On Failure

- Non-fast-forward rejection: **Do not** execute `git push --force` or `git push --force-with-lease`. Inform user of the error message and suggest pulling remote changes with `git pull`.
- Other errors: Report git's error message as-is to the user.

---

### Auto-create Repository Flow (when origin does not exist)

#### Verify GitHub CLI Authentication

```bash
gh auth status
```

If it fails, display and exit:
```
Error: GitHub CLI is not authenticated.
Run: gh auth login
```

#### Determine Visibility

Check if `$ARGUMENTS` contains `--private`:

- `--private` present -> `visibility_flag="--private"`
- `--private` absent -> `visibility_flag="--public"`

#### Get and Sanitize Folder Name

Generate repository name with the following steps:

```bash
name=$(basename "$(pwd)" | tr ' ' '-' | tr -dc '[:alnum:]._-' | sed 's/^[._-]*//' | sed 's/[._-]*$//' | cut -c1-100)
```

- If `name` is empty after sanitization, display and exit:
  ```
  Error: Cannot generate repository name from folder name.
  ```
- Regardless of any transformations, always display:
  ```
  Repository name: <name>
  ```

#### Create Repository

```bash
url=$(gh repo create "$name" $visibility_flag --json url -q '.url')
```

- If a repository with the same name already exists (gh returns an error), display and exit:
  ```
  Error: A repository named <name> already exists on github.com.
  Set origin manually: git remote add origin <url>
  ```
- For other errors: Report gh's error message to the user and exit.

#### Configure Remote and Push

```bash
git remote add origin "$url"
git push --set-upstream origin "$(git branch --show-current)"
```

If push fails, display and exit (**do not delete the created repository**):
```
WARNING: Repository creation and origin configuration succeeded, but push failed.
  origin: <url>
  Retry manually: git push --set-upstream origin <branch>
```

If push succeeds, display a completion message.
