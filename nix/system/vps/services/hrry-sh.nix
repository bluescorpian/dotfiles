{ ... }:
{
  # Harry's portfolio, served as a terminal TUI over SSH. The module is an
  # output of the hrry.sh flake (wired in nix/flake.nix), and everything a
  # visitor sees — content, abuse limits, the persisted host key — is settled
  # over there. This file only says where it listens.
  #
  # Port 22 is the product: `ssh hrry.sh`, no `-p`, on a domain short enough to
  # say out loud. Getting there means taking 22 away from this box's own sshd,
  # which is a sequence rather than an edit — do it by DEPLOY.md in the hrry.sh
  # repo, not by changing this line and deploying. Until that sequence has run,
  # the default port keeps the two daemons out of each other's way.
  services.hrry-sh.enable = true;
}
