{ pkgs, ... }:
{
  # Hermes drives the `claude` CLI on this host (see services/hermes.nix), so
  # the agent toolbox belongs here too — it was previously reaching for `find`
  # and `grep` because ripgrep, fd and jq are declared in home/common.nix,
  # which this host has no home-manager config to import.
  environment.systemPackages = with pkgs; [
    curl
    git
    htop
  ] ++ (import ../../packages/agent-cli.nix { inherit pkgs; });

  # No `rebuild` alias here, deliberately. It used to point at
  # /home/harry/dotfiles — a checkout that drifted ~182 commits stale and
  # predated Hermes, so running it deployed a config that deleted the agent.
  # Repointing it was not an option either: /home/shared/dotfiles, the path the
  # desktop and laptop use, does not exist on this host. The only current
  # checkout here is the agent's own at /var/lib/hermes/workspace/dotfiles.
  #
  # A short alias for "switch this machine to a config from some checkout I
  # have not looked at" is a footgun on a host that is normally deployed
  # remotely with `vps-deploy` from Harry's desktop. Rebuild from here by
  # spelling out the flake ref; hermes.nix documents the form the agent needs
  # (systemd-run, so activation restarting hermes does not kill the rebuild).
}
