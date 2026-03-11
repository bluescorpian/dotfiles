{ modulesPath, lib, pkgs, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "vps";

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.harry = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEi+18q1ME2FMbniwQ276WWakX/j8V19fn37l3G7FTGq dsharryh27@gmail.com"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
  ];

  # SMB share
  services.samba = {
    enable = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "vps";
        security = "user";
        "map to guest" = "never";
      };
      share = {
        path = "/srv/smb";
        browseable = "yes";
        "read only" = "no";
        "valid users" = "harry";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/smb 0700 harry users -"
  ];

  networking.firewall.allowedTCPPorts = [ 22 139 445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "harry" ];
  };

  system.stateVersion = "24.11";
}
