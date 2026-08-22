# User-Scoped Agent Instructions

## Environment

NixOS with flakes. Before reaching for `nix run`, check PATH. Installed
on every host: `git` `curl` `rg` `fd` `tree` `jq` `yq` `gron` `mlr`
`sqlite3` `htmlq` `sd` `sponge` `difft` `shellcheck` `shfmt` `taplo`
`actionlint` `hadolint` `pandoc` `pdftotext` `openssl` `dig`, plus
`ast-grep` — spell that one out, since plain `sg` is shadow's setgid
command. Desktop and laptop additionally: `gh` `tofu` `aws` `node`
`python3` `uv` `magick` `docker`.

For anything genuinely absent, run it without installing (`nix run
nixpkgs#<pkg>`, or `nix-shell -p <pkgs>` for a quick shell), find
packages with `nix search nixpkgs <query>`, and give projects
reproducible dev environments via a `flake.nix` devShell (direnv is
configured).

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

A checkout's current branch is shared state: sibling agents launched from
that directory share one working tree, so switching it relocates their
work. Leave it on the branch you found it on — this overrides the
harness's "if on the default branch, branch first" Bash guidance. Work
that needs its own branch goes in a worktree; branch the checkout itself
only when Harry asks.

## Secrets in tool output

A credential that appears in tool output or a session transcript is not an
incident — transcripts stay local, inference is private, and Harry already
shares private source with you. Don't flag it, and don't propose rotating
it. Publication is where that changes: a secret heading into a commit, a
push, or a paste to an external service still stops the work and gets
raised.

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

## What a durable doc holds

A doc earns its tokens only for what cannot be re-derived: why a decision
went the way it did, what was rejected and on what evidence, an invariant
the code does not show. Anything the repo already answers — a command, or
the code itself — stays where it is answered; a second copy goes stale in
silence or turns a one-file change into a two-file change, and the doc
edit is the one that gets skipped. Generating the copy from a script does
not fix this; it automates the staleness. Before writing a doc, settle
which of those two you are about to do.

## CLAUDE.md hygiene

A CLAUDE.md carries durable facts and stances — never status, progress
notes, or history; those go in commits or nowhere. A fact with a
date on it is usually status in disguise. Every line taxes compliance
with every other line: add a rule on its second occurrence, not its
first, and point at code (`file:line`) rather than quoting it. When a
change you make invalidates a fact in any loaded CLAUDE.md, update that
fact in the same commit. When one has drifted beyond spot fixes, run the
claude-md-audit skill.
