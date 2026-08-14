---
name: claude-md-init
description: Creates a project's first CLAUDE.md — distilled and verified from the code for an existing repo, seeded from the owner's stated decisions for a new one. Use when a repo has no CLAUDE.md, or only an unpruned auto-generated one. Invoked with /claude-md-init.
---

Decide which case the repo is from its history and code volume, then
follow that path. The built-in /init writes a describe-everything
starter; this process replaces it — or prunes its output if one exists.

## Existing codebase — describe, minimally

1. Collect only what an agent could not learn by reading a couple of
   files: commands that can't be guessed, cross-file couplings, other
   actors (CI, deploys, shared checkouts, cron), and conventions where
   following language defaults would be wrong. Everything derivable
   stays out — the repo is the map.
2. Verify each candidate fact against the repo before writing it, with
   read-only subagents told to refute — a wrong founding fact calcifies
   into every future session.
3. Write per the prompt-rules skill. Well under 50 lines.

## New project — prescribe, don't describe

There is nothing to describe yet, and that is the point: the first
sessions will improvise conventions and later sessions will calcify
them. The founding file is the one chance to state standards before
precedent exists.

1. Interview the owner for the decisions they have actually made:
   stack, layering, where things go, the few patterns wanted
   everywhere, hard warnings (public repo, real data, shared infra).
   Offer topics to decide on; never choose for them — an invented
   standard is just improvisation with earlier timing.
2. Write only stated decisions and ungessable commands, around ten
   lines. No aspirations, no description of structure that doesn't
   exist yet.

## Both

Report what was written and what was deliberately left out, and close
with the growth loop: the file gains lines through the gotcha skill on
second occurrences, and gets pruned by the claude-md-audit skill —
never front-load what friction hasn't yet earned.
