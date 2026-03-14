{ domain, ... }:
let
  port = 3007;
  subdomain = "mealie.${domain}";
in {
  services.mealie = {
    enable = true;
    inherit port;
    credentialsFile = "/etc/mealie/credentials.env";
    settings = {
      BASE_URL = "https://${subdomain}";
      TZ = "Africa/Johannesburg";
      OPENAI_BASE_URL = "https://openrouter.ai/api/v1";
      OPENAI_MODEL = "openrouter/healer-alpha";
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
