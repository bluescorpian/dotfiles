{ modulesPath, lib, ... }:
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
    ./services/cockpit.nix
    ./services/n8n.nix
    ./services/homepage.nix
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

  services.vscode-server.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "n8n"
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "harry" ];
  };

  system.stateVersion = "24.11";
}
