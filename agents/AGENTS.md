# User-Scoped Agent Instructions

## Environment

This machine runs **NixOS** with flakes enabled. This has several implications for how you should work:

### NixOS Superpowers

- **Run any package without installing it**: Use `nix run nixpkgs#<package>` or `nix shell nixpkgs#<package>` to temporarily use any package from the 100,000+ in nixpkgs. No `apt install`, no `brew`, no permanent changes. Use this liberally when you need a tool for a one-off task.
- **Create dev environments with flakes**: Use `nix flake init` or write a `flake.nix` with a `devShell` to create reproducible, project-specific development environments. Pair with `direnv` (already configured) for automatic shell activation on `cd`.
- **Explore available packages**: Use `nix search nixpkgs <query>` to find packages.
- **Test NixOS options**: Use `nixos-option` or search the options reference to explore configuration possibilities.
- **Ephemeral shells**: `nix-shell -p pkg1 pkg2` for quick multi-package environments without writing a flake.

## Don't assume exclusive ownership of shared state

When you find something unexpected — a file changed, a process running, a diff you didn't make, a port already bound — resist attributing it to your own most recent action just because it's temporally adjacent. Environments are often shared with other actors: the user working directly in the same directory/terminal, another session on the same branch/repo, a cron job, a background process you didn't spawn. Before undoing, killing, or "fixing" what looks like a stray side effect, check what actually produced it (`git log`, process owner/PID, timestamps, logs) — and ask if it isn't obviously yours. This matters most right before an irreversible action (revert, kill, delete, overwrite).

Corollary: any environment snapshot handed to you at session start (the injected `gitStatus` block, a file listing, a process dump) is frozen at that instant and goes stale as others — or you — act. Never report working-tree state ("X is uncommitted", "the tree is clean") from that snapshot; run `git status` live first. A file that was dirty at session start may have been committed or pushed since.

## Secrets in tool output

A credential that appears in tool output or a session transcript is not an
incident — transcripts stay local, inference is private, and the user already
shares private source with you. Don't flag it, and don't propose rotating
it. Publication is where that changes: a secret heading into a commit, a
push, or a paste to an external service still stops the work and gets
raised.
