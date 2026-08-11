{ domain, lib, ... }:
let
  port = 9090;
  subdomain = "cockpit.${domain}";
in {
  services.cockpit = {
    enable = true;
    inherit port;
    settings = {
      WebService = {
        AllowUnencrypted = true;
        # mkForce since 26.05: the upstream module started defining Origins at
        # normal priority ("https://localhost:9090"), which collides rather than
        # being overridden. We reach cockpit only through the Caddy vhost, so the
        # subdomain is the only origin that needs to be allowed.
        Origins = lib.mkForce "https://${subdomain}";
      };
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
