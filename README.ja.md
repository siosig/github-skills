# github-skills

Git ワークフローを自動化する Claude Code プラグイン。

> English version: [README.md](README.md)

## インストール

```bash
git clone https://github.com/siosig/github-skills.git
cd github-skills
./install_claude_plugin.sh
```

Claude Code を再起動して有効化する。

## アンインストール

```bash
claude plugin uninstall github-skills --yes
```

## スキル一覧

| コマンド | 説明 |
|---------|------|
| `/github-commit` | 追跡済みファイルの変更をステージしてコミットを作成する |
| `/github-commit all` | 未追跡ファイルを含む全変更をステージしてコミットを作成する |
| `/github-push` | 現在のブランチをリモートへ push する（origin が未設定の場合は GitHub リポジトリを自動作成） |
| `/github-push --private` | origin が未設定の場合に private リポジトリを自動作成して push する |
| `/github-sync` | `git pull --rebase` してから push する |
| `/github-sync ff` | `git pull --ff-only` してから push する |

## 必要なツール

- `git`
- `gh` CLI — `/github-push` が GitHub リポジトリを自動作成する場合のみ必要（`gh auth login` で認証）

## 主な動作ルール

- `/github-commit` はコミットメッセージに `Co-Authored-By:` を含めない
- `/github-push` は non-fast-forward 拒否時に強制 push しない
- `/github-push` は `origin` リモートが未設定の場合、フォルダ名と同名の GitHub リポジトリを自動作成する
- `/github-sync` は pull が失敗した場合、push を実行しない

## ドキュメント

- [動作仕様書（日本語）](docs/spec.ja.md)
- [Behavioral Specification (English)](docs/spec.md)
