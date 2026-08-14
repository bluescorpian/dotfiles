# CLAUDE.md

Harry's NixOS dotfiles — the declarative source of truth for his desktop,
laptop, and a Hetzner VPS (`hostname` tells you which host you're on).
Lives at `/home/shared/dotfiles` so both user accounts share one checkout.
`ls` and `nix/flake.nix` are the map; this file keeps only what reading
the repo won't tell you.

> **This repo is public on GitHub.** Before committing, flag anything
> private-looking: keys, tokens, internal hostnames, personal email
> addresses, private IP ranges. When asked to commit such content anyway,
> warn Harry explicitly before proceeding.

## The default task

Most requests are small, surgical edits to a `.nix` file, then `rebuild`,
then commit. Make changes declaratively in this repo, not imperatively on
the running system; prefer a `programs.*`/`services.*` module over a
binary in `home.packages` or a hand-rolled unit. When unsure where
something belongs, prefer the most-shared location and push down only if
it's truly host- or user-specific.

Treat the repo as a living system: when a module outgrows its file or an
option wants to move up or down the sharing ladder, say so inline — one
line, "X wants to move to Y because Z". Flag, don't silently refactor.

## Non-obvious gotchas

- `rebuild` and `rebuild-test` hard-code `/home/shared/dotfiles/nix#$(hostname)`
  (defined in `system/common.nix`). Aliases don't expand inside `bash -c`,
  so scripts need the full command.
- sudo has no TTY here: `sudo -A` routes the prompt to a GUI askpass
  dialog and streams output back normally.
  ```bash
  sudo -A nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)
  ```
- Flakes only see git-tracked files: `git add` any new file before
  `rebuild`, or evaluation fails as if the file doesn't exist — which
  reads confusingly like an unrelated eval error.

## Workflow

Edit → `rebuild` (`rebuild-test` first if risky) → commit only after a
successful switch, one logical change per commit. At the end of every
code-changing turn, list the files you modified and remind Harry they are
uncommitted — a successful `rebuild` is not a commit.

Keybinding changes in any `.nix` file also update the matching JSON in
`keys_cheatsheet/` (viewer: `keys_cheatsheet/start.sh`).

## Researching options

The `nixos` MCP server (wired via `.mcp.json`) injects its own usage
instructions — follow those. When it's unreachable or comes up empty:
`man configuration.nix`, or grep
`/run/current-system/sw/share/doc/nixos/options.html` (~24 MB,
version-matched but frozen at the last rebuild). For opaque build
failures, search the exact error text on the internet — NixOS Discourse,
nixpkgs GitHub issues, and the wiki carry most of them.
