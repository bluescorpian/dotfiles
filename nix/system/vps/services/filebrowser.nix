{ domain, pkgs, ... }:
let
  port = 3006;
  subdomain = "files.${domain}";
in {
  systemd.services.filebrowser = {
    description = "FileBrowser";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.filebrowser}/bin/filebrowser -a 127.0.0.1 -p ${toString port} -r /srv/smb -d /srv/filebrowser/database.db";
      Restart = "always";
      User = "harry";
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/filebrowser 0700 harry users -"
  ];

  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString port}
  '';
}
