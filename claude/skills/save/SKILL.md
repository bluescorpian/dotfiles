---
name: save
description: Save a session handoff note. Use when the user wants to checkpoint progress, end a session, or capture what was worked on. Invoked with /save.
allowed-tools: Bash(date:*), Bash(git log:*), Bash(git branch:*), Bash(git status:*), Write
---

Gather context before writing:
- Today's date: !`date +%Y-%m-%d`
- Current branch: !`git branch --show-current 2>/dev/null || echo "not a git repo"`
- Recent commits: !`git log --oneline -5 2>/dev/null || echo "none"`
- Dirty files: !`git status --short 2>/dev/null || echo "none"`

Write a session handoff note to `docs/session-notes/` + today's date + `.md`.

Structure it as follows — be specific and concrete, not vague:

## Goal
What we were trying to accomplish this session (1–3 sentences).

## Done
Bullet list of completed work. Include file paths, function names, component names where relevant.

## In Progress
What's partially done. State the current condition and exactly where to pick up.

## Next Steps
Ordered list of concrete next actions. Specific enough that a fresh session needs no additional context.

## Decisions
Architectural, design, or implementation decisions made this session, and the reasoning behind them.

## Blockers
Unresolved questions, waiting-on items, or known issues.

---

After writing the file, respond with only:
✓ Session saved → docs/session-notes/YYYY-MM-DD.md
