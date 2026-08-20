---
name: save
description: Sweep the current session for anything that should outlive it — stated preferences, open follow-ups, decisions whose reasoning no commit carries — and file each into memory or the nearest durable home. Use at the end of a session, or when the user wants to be sure something was recorded. Not for freeing context (that is /compact) and not for grading skills or subagents (that is /retro). Invoked with /save.
allowed-tools: Read, Write, Edit, Grep, Glob
---

Work from the transcript you are part of, not from retrieval — you already have every turn at full fidelity.

## What counts

Anything a future session would otherwise have to be told again:

- A preference or working style Harry stated, or a correction that generalises beyond this task (`user` / `feedback`).
- A follow-up, waiting-on, or deliberate deferral, with what unblocks it (`project`).
- A decision and its reasoning, where the commit message does not already carry the reasoning.
- An external resource he pointed you at (`reference`).

Skip what the repo already records — code structure, what a commit did, what a CLAUDE.md already says — and skip work state that ends with this session, which a fresh session picks up from `git log` and the diff.

## Where each item goes

Memory is the default home. Reach past it only when the item is a rule the agent must follow rather than a fact; hand that item to the gotcha ladder and name the rung.

Before writing, read the memory index and any file that half-covers the item: revise it in place rather than adding a near-duplicate, and delete what this session proved wrong.

## Output

One line per item: `<target file> — <new | update | delete> — <the fact in one clause>`. Then stop. Write nothing until Harry replies, and apply only the items he keeps.

If the session produced nothing durable, say so in one line and write nothing.
