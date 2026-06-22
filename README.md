# github-skills

Claude Code plugin providing git workflow skills: `/github-commit`, `/github-push`, `/github-sync`.

## Skills

| Command | Description |
|---------|-------------|
| `/github-commit` | 追跡済みファイルの変更をコミット（`git add -u`） |
| `/github-commit all` | 未追跡ファイルを含む全変更をコミット（`git add -A`） |
| `/github-push` | 現在のブランチを upstream へ push |
| `/github-sync` | `git pull --rebase` してから push |
| `/github-sync ff` | `git pull --ff-only` してから push |

## Rules

- `/github-commit` はコミットメッセージに `Co-Authored-By:` を含めない
- `/github-push` は non-fast-forward 拒否時に強制 push しない
- `/github-sync` は pull が失敗した場合 push を実行しない

## Installation

```bash
git clone https://github.com/siosig/github-skills.git
cd github-skills
./install_claude_plugin.sh
```

Claude Code を再起動して有効化する。

## Uninstall

```bash
claude plugin uninstall github-skills --yes
```
