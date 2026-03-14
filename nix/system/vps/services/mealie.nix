{ domain, ... }:
let
  port = 3007;
  subdomain = "mealie.${domain}";
in {
  services.mealie = {
    enable = true;
    inherit port;
    settings = {
      BASE_URL = "https://${subdomain}";
      TZ = "Africa/Johannesburg";
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
