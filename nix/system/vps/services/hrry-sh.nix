{ domain, hrry-sh-site, ... }:
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

  # The other half of the apex. Ports split it: 22 is the portfolio above, 443
  # is this — a static bundle out of the Nix store, built from the same commit
  # the TUI is (packages.site in the hrry.sh flake). Caddy serves it rather than
  # the Go binary, so nothing web-facing compiles into the daemon.
  #
  # No TLS configuration: the apex is grey-clouded at Cloudflare and resolves
  # straight here, so Caddy's automatic HTTP-01 lands exactly like it does for
  # every subdomain already on this box.
  services.caddy.virtualHosts.${domain}.extraConfig = ''
    root * ${hrry-sh-site}
    file_server
  '';

  # www has pointed here for a while with no vhost to answer it, which is a TLS
  # error rather than a page. The apex is canonical — `ssh hrry.sh` can't carry
  # a `www.`, so the browser address shouldn't either — hence a redirect rather
  # than a second copy of the same root.
  services.caddy.virtualHosts."www.${domain}".extraConfig = ''
    redir https://${domain}{uri} permanent
  '';
}
