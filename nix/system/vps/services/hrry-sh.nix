{ ... }:
{
  # Harry's portfolio, served as a terminal TUI over SSH. The module is an
  # output of the hrry.sh flake (wired in nix/flake.nix), and everything a
  # visitor sees — content, abuse limits, the persisted host key — is settled
  # over there. This file only says where it listens.
  #
  # Port 22 is the product: `ssh hrry.sh`, no `-p`, on a domain short enough to
  # say out loud. This box's own sshd moved to 2222 to free it (see
  # configuration.nix), which was a sequence rather than an edit — DEPLOY.md in
  # the hrry.sh repo is that sequence, and it is what to follow if this ever has
  # to be undone or redone on another box.
  #
  # The module grants CAP_NET_BIND_SERVICE by itself for anything under 1024.
  services.hrry-sh = {
    enable = true;
    port = 22;
  };
}
