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
| `/github-commit` | Stage tracked changes and create a commit |
| `/github-commit all` | Stage all changes (including untracked files) and create a commit |
| `/github-push` | Push the current branch to remote (auto-creates GitHub repo if no origin is set) |
| `/github-push --private` | Push and create a private GitHub repository if origin is missing |
| `/github-sync` | Pull with rebase, then push |
| `/github-sync ff` | Pull with fast-forward only, then push |

## Requirements

- `git`
- `gh` CLI — required only when `/github-push` needs to auto-create a GitHub repository (`gh auth login`)

## Key Behaviors

- `/github-commit` never includes `Co-Authored-By:` in commit messages
- `/github-push` never force-pushes on non-fast-forward rejection
- `/github-push` auto-creates a GitHub repository when no `origin` remote is configured
- `/github-sync` skips push if pull fails

## Documentation

- [Behavioral Specification (English)](docs/spec.md)
- [動作仕様書（日本語）](docs/spec.ja.md)
