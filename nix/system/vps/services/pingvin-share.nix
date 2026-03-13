{ domain, ... }:
let
  subdomain = "share.${domain}";
in {
  services.pingvin-share = {
    enable = true;
    hostname = subdomain;
    https = true;
    backend.port = 3004;
    frontend.port = 3005;
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy /api/* localhost:3004
    reverse_proxy localhost:3005
  '';
}
