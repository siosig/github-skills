---
name: github-sync
description: >
  git pull してから git push する同期操作を行う。
  ユーザーが `/github-sync` または `/github-sync ff` と呼び出した場合に使用する。
  デフォルトは --rebase、`ff` 指定時は --ff-only で pull する。
  pull が失敗した場合は push を実行しない。
allowed-tools: Bash(git pull:*), Bash(git push:*), Bash(git branch:*), Bash(git status:*), Bash(git remote:*)
user-invocable: true
---

## コンテキスト

- 引数: `$ARGUMENTS`
- 現在のブランチ: !`git branch --show-current`
- リモート設定: !`git remote -v`
- 現在の状態: !`git status -sb`

## タスク

リモートの変更を取り込んでから、ローカルのコミットを push する。

### pull の実行

引数 `$ARGUMENTS` を確認する:
- `ff` が含まれる → `git pull --ff-only`
- 引数なし（または `ff` 以外） → `git pull --rebase`

### pull の結果に応じた処理

**pull 成功した場合**: 続けて `git push` を実行する。

**pull が失敗した場合**（コンフリクト、non-fast-forward 拒否 等）:
- `git push` を**実行しない**
- エラーの内容をユーザーに伝える
- コンフリクトの場合: `git rebase --abort` または手動解消の方法を案内する
- `--ff-only` 失敗の場合: `--rebase` の使用か手動 merge を案内する

### push の挙動

pull 成功後の push は `/github-push` と同様:
- upstream 設定済み → `git push`
- upstream 未設定 → `git push --set-upstream origin <current-branch>`
- 強制 push は行わない
