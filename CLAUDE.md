# CLAUDE.md

Harry's NixOS dotfiles — the declarative source of truth for his desktop, laptop, and a Hetzner VPS. Lives at `/home/shared/dotfiles` so both user accounts share one checkout.

## What you'll usually be asked to do

Most requests are **small, surgical edits to `.nix` files** to change the system: install a package, enable a program module, tweak a Hyprland keybind, add a shell alias, spin up a new VPS service, adjust a systemd unit. The loop is almost always: edit the right `.nix` file → `rebuild` → confirm it worked → commit.

Less often: debug why a rebuild failed, refactor a module that's grown messy, update flake inputs, or research a NixOS option. Occasionally a larger structural change (new host, new user, new service module).

Default assumption: the user wants the change made declaratively in this repo, not imperatively on the running system. If something *can* be expressed as a `programs.*` or `services.*` module, prefer that over dropping a binary into `home.packages` or hand-rolling a unit file.

## Mental model

Three `nixosConfigurations` in `nix/flake.nix`: `desktop`, `laptop`, `vps`. The `rebuild` alias picks one via `$(hostname)` — run `hostname` if unsure.

- `nix/system/<host>/` — per-host NixOS config; `system/common.nix` is shared by desktop+laptop (vps is independent).
- `nix/home/` — home-manager; `common.nix` for both users, `home.nix` for personal (harry), `home-smartstation.nix` for work.
- `nix/system/vps/services/` — one file per self-hosted service, each self-contained (systemd unit + Caddy vhost + port). Add a service: drop a file in, import it from `vps/configuration.nix`.

`ls` and `flake.nix` are the source of truth for what exists. Don't expect a file inventory here.

## Working style

Treat this repo as a living system. If you spot duplication across hosts, modules outgrowing their file, options that want to move up to `common.nix` or down to a host file, or a service that wants its own module — **say so inline with the task**. One-line "by the way, X wants to move to Y because Z" is the goal. Flag, don't silently refactor.

## Non-obvious gotchas

- **`rebuild` hard-codes `/home/shared/dotfiles/nix#$(hostname)`** — defined in `system/common.nix`. Aliases don't expand inside `bash -c`, so scripts need the full command.
- **VPS pins nixpkgs-stable**, with `pkgs-unstable` threaded through `specialArgs` for selective unstable packages.
- **Domain `hrry.sh`** is set once in `vps/configuration.nix` and passed via `_module.args`; service files take `{ domain, ... }:`.
- **sudo with no TTY**: `sudo -A` routes the prompt to a `ksshaskpass` GUI dialog and streams output back normally. Use it directly:
  ```bash
  sudo -A nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)
  ```
  On pure SSH/TTY with no graphical session, fall back to `konsole -e bash -c "sudo …; read"` — but Claude can't see that output.

## Workflow

1. Edit the relevant `.nix` file. When unsure where something belongs, prefer the most-shared location (`common.nix`) and push down only if it's truly host- or user-specific.
2. `rebuild` (or `rebuild-vps` for the server). Test with `rebuild-test` if the change is risky.
3. Commit only after a successful switch. One logical change per commit, descriptive message.

## Researching options

- `man configuration.nix`
- `/run/current-system/sw/share/doc/nixos/options.html` (large; grep it)
- `nix search nixpkgs <query>` for packages
- Local docs match this system's nixpkgs version — check them before going online.
