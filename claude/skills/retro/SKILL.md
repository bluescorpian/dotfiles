---
name: retro
description: Post-session retrospective — review this session's corrections and the performance of every skill/subagent that ran, then propose and (on approval) apply CLAUDE.md, rule, skill, or agent changes that would produce a better result with less prompting next time. Invoke at the end of a long or effortful Claude Code session. Invoked with /retro.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(ls:*)
---

Run this in-session, against the actual transcript you're part of — you already have full-fidelity visibility into every tool call, skill invocation, correction, and dead end. Do not reach for conversation-search or any other retrieval; that would only lose fidelity.

Review two separate targets, then produce one combined output.

## A. The work: what did Harry have to supply that a durable artifact should have?

Scan the session for every point where Harry corrected you, hand-walked you through a procedure, restated context he'd already given, or clarified something a fresh session would also stumble on. For each:

- Decide if it's a one-off (skip it) or a pattern worth capturing.
- For patterns, propose a fix using the exact same logic as `/capture-context`: the 8-rung ladder (eliminate the coupling → types → tests → code comment → path-scoped rule → memory → project CLAUDE.md → global AGENTS.md), the same project-vs-global scoping call, and the same "verify live via `claude-code-guide`" discipline for anything version-sensitive. Don't reinvent this — lean on it.

## B. The tooling: how did the skills/subagents that ran actually perform?

For every skill or subagent invoked this session, grade it against:

- **Trigger accuracy** — did it fire when it should have without manual nudging? Did it fire when it shouldn't have?
- **Task success** — did its output need correction or rework?
- **Correction burden** — how much steering did it take mid-run?
- **Efficiency / model fit** — was it run on a model tier that overpaid for the actual difficulty of its task? (See the model policy in `agents/AGENTS.md` — Sonnet is the floor, Opus only for genuinely hard delegated reasoning.)
- **Output quality** — usable as-is, or did it need cleanup?

Ground this rubric in researched Claude Code best practice: a skill's `description` is its trigger and must be specific enough to fire correctly ("pushy," states what and when); CLAUDE.md should stay under ~200 lines; a skill body under ~500 lines with single-depth references; subagents default to Sonnet with Opus reserved for hard reasoning; a fan-out should never leave its model unset.

Propose concrete fixes per skill/agent as warranted: tighten or loosen the `description`, fix or add a body step, narrow or widen `allowed-tools`, pin or adjust `model`/`effort`, split (grown past its budget or doing two jobs) or merge (two skills overlapping), or prune (never earns its keep).

## Output: a selective checklist, never auto-applied

Present every proposed change — from both A and B — as one checklist item each, with the evidence (what happened, roughly when in the session) and the concrete fix. Do not silently apply anything.

For each item Harry approves, apply it immediately in this same run — edit the actual file it targets (CLAUDE.md, the rule, the SKILL.md, the agent file) right then, not deferred to another skill or a future session.

If proposing changes requires summarizing a very long transcript in parts, that fan-out must set `model` explicitly (Sonnet) per the model policy — never leave it unset.

## What you can tune

CLAUDE.md (project and global `agents/AGENTS.md`), path-scoped rules (`.claude/rules/*.md`, `paths:` frontmatter), skills (`SKILL.md` description/body/`allowed-tools`), subagents (`.claude/agents/*.md` — `model`, `effort`, tools), hooks (only for deterministic "whenever X do Y" — never propose one for something that needs judgment), settings permissions, slash commands. If unsure whether a mechanism still behaves as described here, verify live via the `claude-code-guide` agent before proposing it — this product moves fast and a stale assumption baked into a proposal is worse than no proposal.
