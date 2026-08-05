{ domain, ... }:
let
  port = 3004;
  subdomain = "share.${domain}";
in {
  # Replaces pingvin-share, which upstream archived and nixpkgs dropped in 26.05.
  # Send is the maintained timvisee fork of Firefox Send: browser UI, end-to-end
  # encrypted, expiring links. No user accounts, unlike pingvin — links are the
  # only access control, so treat share URLs as secrets.
  services.send = {
    enable = true;
    inherit port;
    baseUrl = "https://${subdomain}";
    # Send keeps upload metadata in redis; nothing else on this host uses one,
    # so let the module provision a dedicated instance rather than sharing.
    redis.createLocally = true;
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
