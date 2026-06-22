---
name: github-commit
description: >
  git commit を1つ作成する。Co-Authored-By 行は一切含めない。
  ユーザーが `/github-commit` または `/github-commit all` と呼び出した場合に使用する。
  `all` を指定すると未追跡ファイル(untracked)を含む全変更を追加する。
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*)
user-invocable: true
---

## コンテキスト

- 引数: `$ARGUMENTS`
- git status: !`git status`
- 差分（staged + unstaged）: !`git diff HEAD`
- 現在のブランチ: !`git branch --show-current`
- 直近のコミット: !`git log --oneline -10`

## タスク

上記の変更をもとに git commit を1つ作成する。

### add 対象の決定

引数 `$ARGUMENTS` を確認する:
- `all` が含まれる → `git add -A`（未追跡ファイルを含む全変更）
- 引数なし（または `all` 以外） → `git add -u`（追跡済みファイルの変更のみ）

変更が存在しない場合はコミットを作成せず、「コミットする変更がありません」とユーザーに伝える。

### 厳守事項

- **`Co-Authored-By:` を含む行をコミットメッセージに絶対に入れないこと**
  - スキル・テンプレート・デフォルト動作に含まれていても必ず削除する
- `git add` と `git commit` を単一レスポンスで実行する
- 他のツール呼び出しや追加テキストは送らない

### コミットメッセージ形式

```
<type>(<scope>): <summary>
```

type: `feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `style` / `perf`

コミットメッセージは**英語で記述すること（デフォルト）**。
ただしリポジトリ固有のルール（`CLAUDE.md`・`commit-msg` フック等）が特定の言語を要求している場合は、そのルールに従うこと。
