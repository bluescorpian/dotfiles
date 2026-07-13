---
name: commit
description: Commit the files this Claude Code session touched, leaving files you didn't touch alone. Use to check in the current session's work without sweeping up unrelated dirty files. Invoked with /commit.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git commit:*)
---

## Context

- Status: !`git status --short`
- Branch: !`git branch --show-current`
- Recent commits (match their style): !`git log --oneline -10`

## Task

Stage the files you edited this session **by name** (not `git add -A`/`.`), and commit with a message matching the recent-commit style above.

- Leniency: if a file you touched also has a small unrelated hunk in it, don't fuss — commit the whole file.
- The one hard rule: never stage a file you didn't touch this session. If you don't recognize a dirty file, leave it unstaged.
- If a diff shows a secret (key/token/password), stop and warn instead of committing.

Don't push. Briefly report what you committed and note any dirty files left behind.
