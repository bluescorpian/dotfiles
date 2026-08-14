# User-Scoped Agent Instructions

## Environment

NixOS with flakes. Lean on it: run any tool without installing (`nix run
nixpkgs#<pkg>`, or `nix-shell -p pkg1 pkg2` for a quick shell), find
packages with `nix search nixpkgs <query>`, and give projects reproducible
dev environments via a `flake.nix` devShell (direnv is configured).

## Don't assume exclusive ownership of shared state

Something unexpected — a changed file, a running process, a diff you
didn't make, a bound port — is not yours just because it appeared after
your last action. The user, another session, a cron job, or a background
process may share this environment. Before undoing, killing, or
overwriting it, check what produced it (`git log`, process owner,
timestamps, logs), and ask when it isn't obviously yours.

Session-start snapshots (the injected `gitStatus`, file listings) freeze
at that instant. Run `git status` live before reporting working-tree
state.

## Reference available context, don't restate it

Anything you author that is read inside an agent session — a skill, doc,
generated prompt, or subagent brief — lands in a context that already has
`CLAUDE.md`/`AGENTS.md` and the repo's own docs loaded. Link to them
instead of copying: restated text bloats context and drifts from its
source. Keep the procedure and what exists nowhere else; if a line would
still be true with the doc deleted, cut it.

## Model policy for delegated work

Applies to everything you delegate — subagents, workflow `agent()` calls —
not to the model you run as.

- Sonnet is the floor and the default; there is no Haiku tier here.
  Reserve Opus for delegated reasoning that is genuinely hard — ambiguous
  synthesis, judgment calls a Sonnet pass already got wrong.
- Set `model` (or `effort`) explicitly on every fan-out. Unset calls
  silently inherit the session model.
- Two deliberate non-fixes; don't re-propose them. Built-in agents
  (Explore, Plan, general-purpose) are left inheriting the session model
  so they can escalate with Harry — don't pin them without asking.
  `CLAUDE_CODE_SUBAGENT_MODEL` stays unset — it would flatten all
  per-call tiering, including legitimate Opus escalations; fix the unset
  fan-out instead.
- This policy is a soft steer; the explicit `model` on every fan-out is
  the enforcement.

## Responses

A response is the interface between work Harry probably didn't watch and
decisions only he can make. Write it like a PR description, not a diary.

- Open with the outcome: the one sentence he'd ask for if he said "just
  the TLDR". Detail after, for the read he may never do.
- Report the delta, not the journey — what is different in the world now.
  "Done" always carries its evidence (the check run and its result);
  unverified work says so.
- Surface every judgment call he might veto: an ambiguity you resolved, a
  precedent you diverged from, scope you trimmed. These are the most
  valuable lines in the response.
- The ask lives in one place, at the end: what you need and what happens
  without it. Nothing needed — say so and stop.
- Gloss each label (section number, finding ID, ticket) in plain language
  on first use per message; bare thereafter. He reads without the doc
  open.
