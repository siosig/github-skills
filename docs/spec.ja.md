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
/github-commit <submodule> [all]
```

任意引数：
- `all` — 未追跡ファイルを含む全変更をステージする（`git add -A`）
- `<submodule>` — submodule のパス。その submodule 内でコミットを作成する

### 説明

現在の変更から git コミットを1つ作成する。デフォルトでは追跡済みファイルのみをステージ（`git add -u`）する。

第1引数が `all` 以外の場合はそれを submodule のパスとみなし、カレントリポジトリではなくその submodule 内（`git -C <submodule>`）でコミットを作成する。

### オプション

| 引数 | 種別 | 既定 | 説明 |
|------|------|------|------|
| `all` | 任意キーワード | — | 未追跡ファイルも含めてコミットする（`git add -A`） |
| `<submodule>` | 任意パス（第1トークン） | — | 指定 submodule 内でコミットする。後ろに `all` を付けられる |

### 動作

1. `$ARGUMENTS` を空白区切りのトークンに分割し、モードを決定する:

   | 引数 | モード | 対象リポジトリ | ステージ |
   |------|--------|----------------|----------|
   | （なし） | リポジトリ | カレント | `git add -u` |
   | `all` | リポジトリ | カレント | `git add -A` |
   | `<submodule>` | submodule | `<submodule>` | `git add -u` |
   | `<submodule> all` | submodule | `<submodule>` | `git add -A` |

   第1トークンが `all` の場合は常にリポジトリモード。それ以外は submodule パスとして扱う（末尾の `/` は除去）。

2. **リポジトリモード**
   1. 上表に従ってステージする。
   2. ステージ後に変更が存在しない場合は「コミットする変更がありません」と報告してコミットを作成せずに終了する。
   3. 差分（`git diff HEAD`）と直近のコミット履歴（`git log --oneline -10`）を分析してコミットメッセージを生成する。
   4. `git add` と `git commit` を単一ステップで実行する。

3. **submodule モード**
   1. `git submodule status -- <submodule>` でパスを検証する。非ゼロ終了または出力が空ならエラーを表示して終了する。
   2. submodule 自身の状態を収集する（`git -C <submodule>` で `status` / `diff HEAD` / `branch --show-current` / `log --oneline -10`）。親リポジトリのコンテキストは submodule の状態を表さないため必須。
   3. submodule が detached HEAD の場合は警告を表示するが処理は継続する。
   4. `git -C <submodule>` でステージとコミットを行う。`cd` は使わない。
   5. ステージ後に変更が存在しない場合は「`<submodule>` にコミットする変更がありません」と報告してコミットを作成せずに終了する。
   6. 親リポジトリの gitlink はステージもコミットもしない。gitlink が変更済みになったことと、記録するには親リポジトリで `/github-commit` を実行する必要があることを報告する。

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
- 作成するコミットは常に1つ。submodule モードでも親リポジトリには一切変更を加えない。

### エラー処理

| 状態 | 動作 |
|------|------|
| ステージ後に変更なし | 「コミットする変更がありません」と報告して終了 |
| `git commit` 失敗 | git のエラーメッセージをそのまま表示 |
| 第1引数が `all` でも登録済み submodule でもない | `Error: '<submodule>' is not a git submodule of this repository.` を表示して終了 |
| submodule が detached HEAD | 警告を表示した上でコミットを作成する |

---

## `/github-push`

### 書式

```
/github-push [private]
```

任意引数：
- `private` — 新規リポジトリを private として作成する（デフォルト: public）

### 説明

現在のブランチをリモート upstream へ push する。`origin` リモートが設定されていない場合は、カレントディレクトリ名と同名の GitHub リポジトリを自動作成して origin に設定してから push する。

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

任意引数：
- `ff` — pull を `--rebase` の代わりに `--ff-only` で実行する

### 説明

リモートの変更を取り込んでからローカルのコミットを push する。pull が成功した場合のみ push を実行する。

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

## `/github-auto-repo`

### 書式

```
/github-auto-repo [private]
```

任意引数：
- `private` — private リポジトリを作成する（デフォルト: public）

### 説明

カレントディレクトリ名と同じ名前の GitHub リポジトリを作成する。ディレクトリ名は自動的にサニタイズされてリポジトリ名となる。

### 動作

#### 事前チェック

1. **git リポジトリ検証**: `git rev-parse --is-inside-work-tree` が成功することを確認。失敗した場合はエラーを表示して終了（終了コード 2）。
2. **GitHub 認証確認**: `gh auth status` を実行。失敗した場合はエラーを表示して終了（終了コード 3）。

#### フォルダ名の処理

1. **ディレクトリ名の取得**: `basename $(pwd)` から取得
2. **サニタイズ**:
   - スペースを `-` に変換
   - `[a-zA-Z0-9_-]` 以外の文字を除去
   - 小文字に変換
   - 39文字に切り詰め
3. **フォールバック**: サニタイズ後の名前が空の場合、親ディレクトリ名を試す（同じサニタイズ処理）
4. **検証**: フォールバック後も空の場合はエラーを表示して終了（終了コード 5）

#### リポジトリの作成

1. **重複チェック**: `gh repo list --source` で同名リポジトリを検索。見つかった場合はエラーを表示して終了（終了コード 4）。
2. **可視性の決定**: `--private` あり → private、なし → public
3. **リポジトリ作成**:
   - Public: `gh repo create <name> --public --source=. --remote=origin`
   - Private: `gh repo create <name> --private --source=. --remote=origin`
   - 失敗した場合はエラーを表示して終了（終了コード 7）

#### ブランチ管理

1. **main ブランチ確認**: main ブランチが存在することを確認（GitHub のデフォルト）
2. **develop ブランチ作成**: `git checkout -b develop`
3. **両ブランチを push**: `git push origin main develop`
   - push 失敗時はエラーを表示して終了（終了コード 7）

#### 成功時の出力

```
✓ リポジトリが正常に作成されました
  名前: <sanitized_name>
  可視性: <public|private>
  リモート: origin
  URL: <github_url>
  ブランチ: main, develop
```

### エラーメッセージ

| 終了コード | 状態 | メッセージ |
|-----------|------|-----------|
| 2 | git リポジトリではない | `Error: Not a git repository.` |
| 3 | GitHub 認証失敗 | `Error: GitHub authentication failed.` |
| 4 | リポジトリが既に存在 | `Error: Repository '<name>' already exists on GitHub.` |
| 5 | 無効なリポジトリ名 | `Error: Folder name cannot be converted to a valid repository name.` |
| 7 | ネットワーク・push エラー | `Error: Failed to create repository. Check your permissions or network.` |

### 使用ツール

`git`, `gh`, `basename`, `grep`, `sed`, `tr`, `cut`

### 主な特徴

- main と develop の 2つのブランチを自動作成
- 既存リポジトリの再利用や上書きをしない
- サニタイズされたリポジトリ名をユーザーに確認させる
- 回復手順なしのシンプルなエラーメッセージ
- すべての操作は原子的（完全成功または完全失敗、部分的な状態を残さない）

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
