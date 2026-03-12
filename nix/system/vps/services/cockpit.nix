{ domain, ... }:
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
        Origins = "https://${subdomain}";
      };
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
