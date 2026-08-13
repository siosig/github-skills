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
| `/github-commit [all]` | 追跡済みファイルの変更をステージしてコミットを作成する（`all` で未追跡ファイルも含める） |
| `/github-commit <submodule> [all]` | カレントリポジトリではなく指定した submodule 内でコミットを作成する |
| `/github-push [private]` | 現在のブランチをリモートへ push する（origin 未設定時は GitHub リポジトリを自動作成、`private` で private リポジトリ） |
| `/github-sync [ff]` | `git pull --rebase` してから push する（`ff` で `--ff-only` を使用） |
| `/github-sync <submodule> [ff]` | 指定した submodule 内で pull → push の同期を実行する |
| `/github-auto-repo [private]` | 現在のフォルダと同名の GitHub リポジトリを作成する（`private` で private リポジトリ） |
| `/github-main-merge` | 現在のブランチを `main`（`main` がなければ `master`）へマージして `origin` へ push する（タグは作成しない） |

## 必要なツール

- `git`
- `gh` CLI — `/github-push` が GitHub リポジトリを自動作成する場合のみ必要（`gh auth login` で認証）

## 主な動作ルール

- `/github-commit` はコミットメッセージに `Co-Authored-By:` を含めない
- `/github-commit <submodule>` は submodule 内だけをコミットする。親リポジトリの gitlink 更新は別途 `/github-commit` を実行する
- `/github-push` は non-fast-forward 拒否時に強制 push しない
- `/github-push` は `origin` リモートが未設定の場合、フォルダ名と同名の GitHub リポジトリを自動作成する
- `/github-sync` は pull が失敗した場合、push を実行しない
- `/github-sync <submodule>` は submodule が detached HEAD または `origin` 未設定の場合は実行を拒否し、リモートの自動作成も行わない
- `/github-main-merge` はマージ先として `main` を優先し、`main` がないリポジトリでは `master` を使う。未コミットの変更がある場合は実行を拒否し、強制 push を行わず、成功後は元のブランチへ復帰する

## ドキュメント

- [動作仕様書（日本語）](docs/spec.ja.md)
- [Behavioral Specification (English)](docs/spec.md)
