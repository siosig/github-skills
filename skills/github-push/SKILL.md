---
name: github-push
description: >
  現在のブランチを upstream へ git push する。
  ユーザーが `/github-push` と呼び出した場合に使用する。
  upstream 未設定の場合は --set-upstream origin <branch> で push する。
  non-fast-forward 拒否時は強制 push を行わない。
allowed-tools: Bash(git push:*), Bash(git branch:*), Bash(git remote:*)
user-invocable: true
---

## コンテキスト

- 現在のブランチ: !`git branch --show-current`
- リモート設定: !`git remote -v`
- Upstream の状態: !`git status -sb`

## タスク

現在のブランチをリモートへ push する。

### push の実行

upstream ブランチの設定状況を確認する:
- upstream 設定済み → `git push`
- upstream 未設定（`git status -sb` の1行目に `[origin/...]` がない）→ `git push --set-upstream origin <current-branch>`

### 失敗時の挙動

- non-fast-forward で拒否された場合: `git push --force` または `git push --force-with-lease` を**実行しない**。エラーメッセージをユーザーに伝え、`git pull` でリモートの変更を取り込むよう促す。
- その他のエラー: git のエラーメッセージをそのままユーザーに伝える。
