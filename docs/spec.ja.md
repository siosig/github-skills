# github-skills — 動作仕様書

> English version: [spec.md](spec.md)

**プラグイン**: `github-skills`  
**バージョン**: 1.0.0  
**最終更新**: 2026-06-22

---

## 概要

本書は `github-skills` Claude Code プラグインが提供するすべてのスキルの動作仕様を記述する。各スキルはユーザーがスラッシュコマンド（例: `/github-commit`）で呼び出し、カレントディレクトリで実行される。

---

## `/github-commit`

### 書式

```
/github-commit [all]
```

### 説明

現在の変更から git コミットを1つ作成する。デフォルトでは追跡済みファイルのみをステージ（`git add -u`）する。`all` を指定すると未追跡ファイルも含めてステージ（`git add -A`）する。

### オプション

| 引数 | 種別 | デフォルト | 説明 |
|------|------|-----------|------|
| `all` | 任意キーワード | — | 未追跡ファイルを含む全変更をステージする（`git add -A`） |

### 動作

1. `$ARGUMENTS` を確認してステージ戦略を決定する:
   - `all` が含まれる → `git add -A`
   - それ以外 → `git add -u`
2. ステージ後に変更が存在しない場合は「コミットする変更がありません」と報告してコミットを作成せずに終了する。
3. 差分（`git diff HEAD`）と直近のコミット履歴（`git log --oneline -10`）を分析してコミットメッセージを生成する。
4. `git add` と `git commit` を単一ステップで実行する。

### コミットメッセージ形式

```
<type>(<scope>): <summary>
```

| フィールド | 値 |
|-----------|-----|
| `type` | `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf` |
| `scope` | 変更ファイルのパスから導出（任意） |
| `summary` | 英語で簡潔に記述 |

コミットメッセージは**デフォルトで英語**で記述する。リポジトリ固有のルール（`CLAUDE.md`、`commit-msg` フック等）が言語を指定している場合はそれに従う。

### 制約

- `Co-Authored-By:` をコミットメッセージに**絶対に含めない**。テンプレートやデフォルト動作に含まれていても削除する。
- コミット後に push しない。

### エラー処理

| 状態 | 動作 |
|------|------|
| ステージ後に変更なし | 「コミットする変更がありません」と報告して終了 |
| `git commit` 失敗 | git のエラーメッセージをそのまま表示 |

---

## `/github-push`

### 書式

```
/github-push [--private]
```

### 説明

現在のブランチをリモート upstream へ push する。`origin` リモートが設定されていない場合は、カレントディレクトリ名と同名の GitHub リポジトリを自動作成して origin に設定してから push する。

### オプション

| 引数 | 種別 | デフォルト | 説明 |
|------|------|-----------|------|
| `--private` | 任意フラグ | — | 新規リポジトリを private として作成する（デフォルト: public） |

### 動作

#### 事前チェック

カレントディレクトリが git リポジトリであることを確認する。そうでない場合はエラーを表示して終了する。

#### origin が存在する場合

`git remote get-url origin` が成功した場合:

| 状態 | 動作 |
|------|------|
| upstream ブランチが設定済み | `git push` |
| upstream ブランチが未設定 | `git push --set-upstream origin <branch>` |
| non-fast-forward で拒否 | エラーを報告して `git pull` を促す。**強制 push しない** |
| その他のエラー | git のエラーメッセージをそのまま表示 |

#### origin が未設定の場合 — 自動作成フロー

`origin` リモートが設定されていない場合:

1. **認証確認**: `gh auth status` を実行する。未認証の場合は `gh auth login` の実行を促してエラー終了する。
2. **可視性の決定**: `--private` あり → private、なし → public。
3. **リポジトリ名のサニタイズ**: カレントディレクトリ名から以下の変換でリポジトリ名を生成する:
   - スペースを `-` に変換
   - `[a-zA-Z0-9._-]` 以外の文字を除去
   - 先頭・末尾の `.`、`-`、`_` を除去
   - 100文字に切り詰め
   - 結果が空の場合はエラーを表示して終了する。
   - 変換後の名前を常にユーザーに表示する。
4. **リポジトリ作成**: `gh repo create <name> --public|--private --json url -q '.url'`
   - 同名リポジトリが github.com にすでに存在する場合はエラーを表示して終了する。自動的に origin を設定**しない**。
5. **リモート設定**: `git remote add origin <url>`
6. **push**: `git push --set-upstream origin <branch>`
   - push 失敗時: エラーと手動再試行手順を表示する。**作成済みリポジトリは削除しない**。

### エラーメッセージ

| 状態 | メッセージ |
|------|-----------|
| git リポジトリ外 | `エラー: git リポジトリではありません。` |
| gh 未認証 | `エラー: GitHub CLI が認証されていません。\n実行してください: gh auth login` |
| リポジトリ名生成不可 | `エラー: フォルダ名からリポジトリ名を生成できません。` |
| 同名リポジトリ存在 | `エラー: github.com に同名のリポジトリ (<name>) が既に存在します。\n手動で origin を設定してください: git remote add origin <url>` |
| push 失敗（作成後） | `⚠ リポジトリの作成と origin の設定は完了しましたが、プッシュが失敗しました。\n  origin: <url>\n  手動で再試行してください: git push --set-upstream origin <branch>` |

### 使用ツール

`git`, `gh`, `basename`, `tr`, `sed`, `cut`

---

## `/github-sync`

### 書式

```
/github-sync [ff]
```

### 説明

リモートの変更を取り込んでからローカルのコミットを push する。pull が成功した場合のみ push を実行する。

### オプション

| 引数 | 種別 | デフォルト | 説明 |
|------|------|-----------|------|
| `ff` | 任意キーワード | — | pull を `--rebase` の代わりに `--ff-only` で実行する |

### 動作

1. **pull の実行**:
   - `ff` あり → `git pull --ff-only`
   - なし → `git pull --rebase`
2. **pull が成功した場合**: push を実行する（origin 設定済みの `/github-push` と同じロジック）:
   - upstream 設定済み → `git push`
   - upstream 未設定 → `git push --set-upstream origin <branch>`
3. **pull が失敗した場合**: push を**実行しない**。エラーを報告して復旧方法を案内する:
   - rebase 中のコンフリクト → `git rebase --abort` または手動解消を案内
   - `--ff-only` が拒否された場合 → `--rebase` の使用か手動 merge を案内
4. **強制 push しない**。

### エラー処理

| 状態 | 動作 |
|------|------|
| pull コンフリクト | コンフリクトを報告して `git rebase --abort` を案内 |
| `--ff-only` 拒否 | `git pull --rebase` または手動 merge を案内 |
| push 失敗 | git のエラーメッセージをそのまま表示 |

---

## 計画中のスキル

以下のスキルは仕様策定中であり、まだ実装されていない:

| コマンド | 説明 |
|---------|------|
| `/github-beta [X.Y.Z]` | 現在のブランチを `develop` にマージし、`vX.Y.Z-beta.n` タグを付けて push する |
| `/github-release [X.Y.Z]` | 現在のブランチを `main` にマージし、`vX.Y.Z` タグを付けて push する |

詳細な仕様は [specs/003-release-flow/spec.md](../specs/003-release-flow/spec.md) を参照。

---

## 共通制約

特に明記しない限り、すべてのスキルに適用される:

- スキルはカレントディレクトリで動作する
- スキルは強制 push（`--force`、`--force-with-lease`）を実行しない
- スキルは内部ツールのエラーメッセージをそのままユーザーに伝える（エラーを隠蔽しない）
- スキルは各ステップの進捗をユーザーに明確に報告する
