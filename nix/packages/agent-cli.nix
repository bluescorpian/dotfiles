# CLI toolbox for the coding agents on this fleet (Claude Code on the desktop
# and laptop, the Hermes-driven `claude` on the VPS).
#
# Why a shared list rather than home.packages: the VPS runs an agent too but has
# no home-manager config, so anything declared there never reaches it. Imported
# by home/common.nix and system/vps/packages.nix.
#
# Why these tools specifically: Claude Code's `tengu_thrifty_sonic` mode tells
# the agent to do its file work through Bash — cat/sed/grep/heredocs — instead of
# the dedicated read and edit tools, because it costs fewer tokens. That moves
# real risk into the shell, so this list is weighted toward making those writes
# safe and checkable rather than toward nicer output for a human reader.
#
# Deliberately absent: pagers and interactive niceties (bat, delta, eza, fzf) —
# an agent reads raw text, so they are closure cost with no benefit. Also absent:
# prettier, ruff, eslint and friends. Those must match each project's pinned
# version; a global copy invites reformatting a repo with the wrong one. They
# belong in per-project devShells.
{ pkgs }:

with pkgs; [
  # Search and navigate. rg and fd are also the two the VPS was missing
  # outright, which left its agent falling back to bare find/grep.
  ripgrep
  fd
  tree

  # Structured read/write. jq covers JSON; yq-go brings the same syntax to
  # YAML, TOML and XML, and unlike jq it edits in place with -i.
  jq
  yq-go
  gron # flattens JSON to grep-able assignment lines; `gron -u` reverses it
  miller # `mlr` — CSV/TSV/JSONL
  sqlite # `sqlite3`, for reading .db files in place
  htmlq # jq for HTML; pairs with the curl already on every host

  # Safe edits. sponge (moreutils) is the important one: `jq '...' f > f`
  # truncates f to zero before jq ever reads it, and `| sponge f` is the fix.
  # sd takes literal strings, so replacements containing / or regex
  # metacharacters do not need escaping the way sed's do.
  moreutils
  sd

  # Structural edits and review. ast-grep matches syntax rather than text, so
  # it skips hits inside comments and string literals that sed always catches;
  # difftastic then shows what a bulk rewrite actually changed.
  #
  # Note: ast-grep also ships a short `sg` alias, which is unreachable here —
  # shadow's setgid `sg` sits in /run/wrappers and wins on PATH. Call it
  # `ast-grep`.
  ast-grep
  difftastic

  # Checking what was written. The agent authors shell constantly under
  # thrifty mode, and nothing was linting it before.
  shellcheck
  shfmt
  taplo # TOML formatter/validator
  actionlint # GitHub Actions workflows
  hadolint # Dockerfiles

  # Reading documents and images. Everything below earned its place from the
  # session transcripts rather than from a guess: counts are `nix run
  # nixpkgs#<pkg>` invocations across ~/.claude/projects.
  pandoc # 25 invocations — document conversion
  poppler-utils # 10 — `pdftotext` and friends. Note the attribute is
  #      hyphenated; half those calls used poppler_utils and failed.
  openssl # 7 — certificate and key inspection
  dnsutils # 12 — `dig`. Off-theme for file work, but it recurs and is tiny.

  # No Nix formatter here on purpose: this repo has never had one (no flake
  # `formatter` output, no treefmt), so adding one would set a convention and
  # make the first repo-wide run a huge diff. Add nixfmt here if that changes.
]
