{ modulesPath, ... }:
let
  domain = "hrry.sh";
in {
  _module.args = { inherit domain; };
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./hardware-configuration.nix
    ./packages.nix
    ./samba.nix
    ./services/vaultwarden.nix
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

  services.caddy.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "harry" ];
  };

  system.stateVersion = "24.11";
}
