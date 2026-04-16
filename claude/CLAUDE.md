# User-Scoped CLAUDE.md

## Environment

This machine runs **NixOS** with flakes enabled. This has several implications for how you should work:

### NixOS Superpowers

- **Run any package without installing it**: Use `nix run nixpkgs#<package>` or `nix shell nixpkgs#<package>` to temporarily use any package from the 100,000+ in nixpkgs. No `apt install`, no `brew`, no permanent changes. Use this liberally when you need a tool for a one-off task.
- **Create dev environments with flakes**: Use `nix flake init` or write a `flake.nix` with a `devShell` to create reproducible, project-specific development environments. Pair with `direnv` (already configured) for automatic shell activation on `cd`.
- **Explore available packages**: Use `nix search nixpkgs <query>` to find packages.
- **Test NixOS options**: Use `nixos-option` or search the options reference to explore configuration possibilities.
- **Ephemeral shells**: `nix-shell -p pkg1 pkg2` for quick multi-package environments without writing a flake.
