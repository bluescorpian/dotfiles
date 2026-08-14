# VPS (Hetzner)

Pins nixpkgs-stable; `pkgs-unstable` comes in via `specialArgs` for
selective unstable packages. The domain `hrry.sh` is set once in
`configuration.nix` and passed to service files via `_module.args`.

The `hrry-sh` flake input is a **private** repo, fetched over `git+ssh` with a
read-only deploy key at `/root/.ssh/id_ed25519` — root's, because deploys
evaluate as root. It is the one piece of this host that isn't declarative: a
private key can't live in a public repo. Rebuilding the box means a new keypair
and a new deploy key on `bluescorpian/hrry.sh`.

Deploy with `vps-deploy` only — it tells the box to pull and rebuild from
its own checkout. Never deploy from a checkout here: Hermes edits the
checkout on the box directly, and the two silently overwrite each other.
