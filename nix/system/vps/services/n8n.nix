{ domain, ... }:
let
  port = 3002;
  subdomain = "n8n.${domain}";
in {
  # 26.05 removed `services.n8n.settings` (mkRemovedOptionModule) in favour of
  # `environment`, which maps straight onto n8n's own env vars — so the old
  # `port` attribute is now `N8N_PORT`. Migrated pre-emptively: this file is
  # currently disabled in configuration.nix, so re-enabling it unchanged would
  # have failed evaluation rather than anything visible right now.
  services.n8n = {
    enable = true;
    environment = {
      N8N_PORT = port;
      N8N_HOST = subdomain;
      N8N_PROTOCOL = "https";
      WEBHOOK_URL = "https://${subdomain}/";
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
