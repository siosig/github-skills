# github-skills

Claude Code plugin that provides Git workflow automation skills.

> Japanese version: [README.ja.md](README.ja.md)

## Installation

```bash
git clone https://github.com/siosig/github-skills.git
cd github-skills
./install_claude_plugin.sh
```

Restart Claude Code to activate.

## Uninstall

```bash
claude plugin uninstall github-skills --yes
```

## Skills

| Command | Description |
|---------|-------------|
| `/github-commit [all]` | Stage tracked changes and create a commit (add `all` to include untracked files) |
| `/github-push [private]` | Push the current branch to remote (add `private` to create private repo if origin is missing) |
| `/github-sync [ff]` | Pull with rebase, then push (add `ff` to use fast-forward only) |
| `/github-auto-repo [private]` | Create a GitHub repository matching the folder name (add `private` for private repo) |
| `/github-main-merge` | Merge the current branch into `main` and push it to `origin`, with no tag created |

## Requirements

- `git`
- `gh` CLI — required only when `/github-push` needs to auto-create a GitHub repository (`gh auth login`)

## Key Behaviors

- `/github-commit` never includes `Co-Authored-By:` in commit messages
- `/github-push` never force-pushes on non-fast-forward rejection
- `/github-push` auto-creates a GitHub repository when no `origin` remote is configured
- `/github-sync` skips push if pull fails
- `/github-main-merge` refuses to run with uncommitted changes, never force-pushes, and returns to the original branch after a successful run

## Documentation

- [Behavioral Specification (English)](docs/spec.md)
- [動作仕様書（日本語）](docs/spec.ja.md)
