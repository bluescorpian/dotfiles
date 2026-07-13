---
name: capture-context
description: Route a single learning, gotcha, stale doc, or process fix to its cheapest durable home instead of bloating CLAUDE.md or piling up memory notes. Invoke when you or the agent notice a recurring mistake, a doc that misled the agent, or missing context that cost extra prompting. Invoked with /capture-context.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash(git status:*), Bash(git diff:*), Bash(ls:*)
---

Handle exactly one learning per invocation. If several surfaced, ask which one (or run this again per item) rather than batching them.

## 1. Diagnose

State plainly: what happened, why it cost tokens or extra prompting, and the root cause (not just the symptom). If the root cause is unclear, say so — don't force a home onto a fix you don't actually understand yet.

## 2. Scope: project vs global

- **Project** (this repo's `CLAUDE.md`, a rule, a memory note) — true for this codebase, not necessarily others.
- **Global** (`agents/AGENTS.md`, which deploys to `~/.claude/CLAUDE.md`) — true across every project you work in. Default to project scope; only go global when the learning is genuinely about how you work, not about this repo.

## 3. Walk the rung ladder, stop at the first rung that actually fixes it

Cheapest and most durable first — each rung below it is progressively more expensive (it costs tokens every session) and less durable (prose drifts, code doesn't):

1. **Eliminate the coupling.** Can the code be refactored so the mistake is structurally impossible? Best fix — no context cost, ever.
2. **Make it fail to compile / typecheck.** Encode the constraint in types or a schema.
3. **Make it fail a test.** Encode the constraint as a test.
4. **Code-local comment.** One line, at the exact spot, explaining the non-obvious *why* — not what the code does.
5. **Path-scoped rule** (`.claude/rules/<name>.md` with a `paths:` frontmatter glob). Loads only when a matching file is opened — zero cost the rest of the time. Best fit for "editing file A also requires touching file B" coupling, or a convention scoped to one directory/filetype.
6. **Auto-memory topic file** (`type: project` or `feedback` in the memory dir). For facts, preferences, or "why" context that isn't code-adjacent and doesn't belong in every session.
7. **Project `CLAUDE.md`.** Only for facts relevant to *every* session in this repo that can't be scoped narrower than that.
8. **Global `agents/AGENTS.md`.** Last resort — only for facts true across all of your projects.

## 4. Fix or prune existing context — don't just append

Before writing anything new, check whether an existing rule, memory note, or CLAUDE.md line already half-covers this and is stale, wrong, or duplicated. Reconcile it in place. Accumulating near-duplicate notes is itself a form of context bloat.

## 5. Keep prose at slow-changing altitude

Never bake a version-sensitive specific (an exact flag, option name, or CLI syntax) into a rule or CLAUDE.md without a live-verify note. Claude Code and its ecosystem move fast — if the learning includes something that could plausibly change, phrase it as "verify via the `claude-code-guide` agent before relying on this" rather than hardcoding it as fact.

## 6. Apply it

Make the edit at the chosen rung directly.

## 7. Report

State: what changed, which file, which rung you landed on, and why not a rung higher or lower.
