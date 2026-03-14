{ domain, pkgs-unstable, ... }:
let
  port = 3007;
  subdomain = "mealie.${domain}";
in {
  services.mealie = {
    enable = true;
    package = pkgs-unstable.mealie;
    inherit port;
    credentialsFile = "/etc/mealie/credentials.env";
    settings = {
      BASE_URL = "https://${subdomain}";
      TZ = "Africa/Johannesburg";
      NLTK_DATA = "/var/lib/mealie/nltk_data";
      OPENAI_BASE_URL = "https://openrouter.ai/api/v1";
      OPENAI_MODEL = "openrouter/healer-alpha";
    };
  };

  systemd.services.mealie.serviceConfig.BindPaths = [ "/var/lib/mealie/nltk_data:/nltk_data" ];

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
