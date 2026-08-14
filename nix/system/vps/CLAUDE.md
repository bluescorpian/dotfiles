# VPS (Hetzner)

Pins nixpkgs-stable; `pkgs-unstable` comes in via `specialArgs` for
selective unstable packages. The domain `hrry.sh` is set once in
`configuration.nix` and passed to service files via `_module.args`.

Deploy with `vps-deploy` only — it tells the box to pull and rebuild from
its own checkout. Never deploy from a checkout here: Hermes edits the
checkout on the box directly, and the two silently overwrite each other.
