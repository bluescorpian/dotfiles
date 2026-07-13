# User-Scoped Agent Instructions

## Environment

This machine runs **NixOS** with flakes enabled. This has several implications for how you should work:

### NixOS Superpowers

- **Run any package without installing it**: Use `nix run nixpkgs#<package>` or `nix shell nixpkgs#<package>` to temporarily use any package from the 100,000+ in nixpkgs. No `apt install`, no `brew`, no permanent changes. Use this liberally when you need a tool for a one-off task.
- **Create dev environments with flakes**: Use `nix flake init` or write a `flake.nix` with a `devShell` to create reproducible, project-specific development environments. Pair with `direnv` (already configured) for automatic shell activation on `cd`.
- **Explore available packages**: Use `nix search nixpkgs <query>` to find packages.
- **Test NixOS options**: Use `nixos-option` or search the options reference to explore configuration possibilities.
- **Ephemeral shells**: `nix-shell -p pkg1 pkg2` for quick multi-package environments without writing a flake.

## Git safety: don't assume an unattributed diff is yours to revert

If you find an unexpected change in a working tree (e.g. after a background agent/workflow job finishes) that none of your own prompts/edits explain, don't assume the job caused it and revert it. The user — or another process — may be working directly in that same directory concurrently (this is especially likely in git worktrees dedicated to a session, since worktrees share one object database/refs and the user can commit into one directly while you work in it). Before running any destructive git command (`checkout --`, `reset`, `restore`, `clean`) to undo an unattributed change: check `git log -- <path>` to see if it's already committed, and ask the user what it is rather than guessing. Reverting the wrong thing can silently discard real, intentional work — it's exactly the kind of action the git-safety protocol exists to gate.

## Model policy for delegated work

Applies to every subagent, workflow `agent()` call, or task you delegate — not to the model you yourself are running as.

- **Sonnet is the floor and default.** Most delegated work (search, summarization, mechanical edits, verify/vote passes, single-claim checks) is Sonnet-level work. Use it unless a specific call needs more.
- **Opus is for genuinely hard delegated reasoning** — non-obvious architecture tradeoffs, ambiguous synthesis across many conflicting sources, judgment calls a Sonnet pass has already gotten wrong. Reach for it deliberately, not by default.
- **No Haiku tier.** Sonnet is the cheapest tier in use here.
- **Never leave a fan-out's model unset.** A workflow or batch of parallel agents with no explicit `model` silently inherits the parent session's model — if you (Claude, reading this) are running as Opus, every unset agent call runs as Opus too. This has caused real cost incidents (one `/deep-research` run spawned 106 agents, all unset, all on Opus, burning about half a 5-hour usage window on tasks — mostly single-claim verify votes — that needed nothing like Opus). Before any fan-out, set `model` (or `effort`) per call, or per phase, deliberately.
- **Built-in agents (Explore, Plan, general-purpose) inherit the session model, uncapped.** As of Claude Code v2.1.198 this changed from Explore always running on Haiku to inheriting the session model (capped at Opus). This is a known, intentional tradeoff here — Harry drives Opus sessions and wants Explore/Plan able to escalate with him, so it is deliberately left inheriting rather than pinned down via a `~/.claude/agents/Explore.md` shadow. Don't "fix" this by pinning it without asking first.
- **`CLAUDE_CODE_SUBAGENT_MODEL` is deliberately not set.** It exists as a blanket override (env var > per-call `model` > agent frontmatter `model` > inherited session model) but it would flatten all per-call tiering above it, including legitimate Opus escalations. This was considered and rejected — don't propose it as a fix for cost overruns; fix the unset fan-out instead.
- This policy is a soft steer (CLAUDE.md/AGENTS.md influence, not a hard guarantee) — the discipline above (always set `model` explicitly on fan-outs) is what actually enforces it.
