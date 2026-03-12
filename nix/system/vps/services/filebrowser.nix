{ domain, ... }:
let
  port = 3006;
  subdomain = "files.${domain}";
in {
  services.filebrowser = {
    enable = true;
    settings = {
      port = port;
      root = "/srv/smb";
      address = "127.0.0.1";
    };
  };

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
