{ domain, pkgs-unstable, ... }:
let
  port = 3001;
  subdomain = "vault.${domain}";
in {
  services.vaultwarden = {
    enable = true;
    package = pkgs-unstable.vaultwarden;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = port;
      DOMAIN = "https://${subdomain}";
      SIGNUPS_ALLOWED = true;
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
