{ ... }:
{
  services.samba = {
    enable = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "vps";
        security = "user";
        "map to guest" = "never";
        "unix extensions" = "yes";
        "ea support" = "yes";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
      };
      share = {
        path = "/srv/smb";
        browseable = "yes";
        "read only" = "no";
        writable = "yes";
        "valid users" = "harry";
        "vfs objects" = "fruit streams_xattr";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force user" = "harry";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/smb 0700 harry users -"
  ];

  networking.firewall.allowedTCPPorts = [ 139 445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
}
