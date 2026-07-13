---
name: commit-all
description: Commit everything dirty, including files this session didn't touch — glancing at the unfamiliar changes first so the message describes them honestly. Use to sweep the whole working tree into a commit. Invoked with /commit-all.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git commit:*)
---

## Context

- Status: !`git status --short`
- Full diff: !`git diff HEAD`
- Recent commits (match their style): !`git log --oneline -10`

## Task

Stage everything (`git add -A`) and commit. Unlike `/commit`, this includes files you didn't touch this session — so read their diff first and let the commit message reflect what they actually change, not just your own work.

- If the tree holds clearly unrelated concerns, split into a couple of logical commits; otherwise one is fine.
- If a diff shows a secret (key/token/password), stop and warn instead of committing.

Don't push. Briefly report what you committed.
