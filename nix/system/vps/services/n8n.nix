{ domain, ... }:
let
  port = 3002;
  subdomain = "n8n.${domain}";
in {
  services.n8n = {
    enable = true;
    settings = {
      port = port;
      N8N_HOST = subdomain;
      N8N_PROTOCOL = "https";
      WEBHOOK_URL = "https://${subdomain}/";
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
