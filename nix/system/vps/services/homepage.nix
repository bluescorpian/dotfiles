{ domain, ... }:
let
  port = 3003;
in {
  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
    settings = {
      title = "hrry.sh";
      favicon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png";
    };
    services = [
      {
        "Services" = [
          {
            "Vaultwarden" = {
              icon = "vaultwarden";
              href = "https://vault.${domain}";
              description = "Password manager";
            };
          }
          {
            "n8n" = {
              icon = "n8n";
              href = "https://n8n.${domain}";
              description = "Workflow automation";
            };
          }
          {
            "Cockpit" = {
              icon = "cockpit";
              href = "https://cockpit.${domain}";
              description = "Server management";
            };
          }
          {
            "Pingvin Share" = {
              icon = "pingvin-share";
              href = "https://share.${domain}";
              description = "File sharing";
            };
          }
          {
            "FileBrowser" = {
              icon = "filebrowser";
              href = "https://files.${domain}";
              description = "File manager";
            };
          }
          {
            "Mealie" = {
              icon = "mealie";
              href = "https://mealie.${domain}";
              description = "Recipe manager";
            };
          }
        ];
      }
    ];
  };

  services.caddy.virtualHosts."home.${domain}".extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
