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
    # ./services/n8n.nix  # temporarily disabled
    ./services/homepage.nix
    ./services/send.nix
    ./services/filebrowser.nix
    ./services/mealie.nix
    ./services/hermes.nix
  ];

  time.timeZone = "Africa/Johannesburg";

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

  swapDevices = [{
    device = "/swapfile";
    size = 4096; # 4GB
  }];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "n8n"
    "claude-code"
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "harry" ];

    # claude-code is a 354 MiB closure and the overlay builds it outside
    # cache.nixos.org, so without this every bump would be pushed up this
    # uplink from the desktop instead of substituted here. Same cache the
    # desktop and laptop already trust (system/common.nix).
    #
    # Safe to list just this one: NixOS appends the default cache rather than
    # replacing it — the desktop's generated nix.conf ends with
    # `... https://cache.nixos.org/`, even though common.nix never names it.
    substituters = [ "https://claude-code.cachix.org" ];
    trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];

    # Demand-driven GC, which the timer below cannot provide: the nix-daemon
    # collects garbage *during* an operation whenever free space drops under
    # min-free, freeing up to max-free. A single deploy can outgrow the disk
    # long before any scheduled run fires — hermes alone is a multi-GB closure
    # on a 37 GB disk — so the timer is the floor and this is the safety net.
    min-free = 2 * 1024 * 1024 * 1024; # 2 GiB: start collecting
    max-free = 8 * 1024 * 1024 * 1024; # 8 GiB: stop collecting
  };

  # Automatic garbage collection. Deliberately duplicated from system/common.nix
  # rather than imported — common.nix is desktop-only (Plasma, X11, systemd-boot,
  # Docker) and conflicts with this host on stateVersion, sshd and bootloader.
  #
  # Tighter than the desktop's 30d/weekly: each system generation here pins a
  # whole hermes closure, so a few redeploys inside one retention window can
  # stack several GB of otherwise-dead paths. The current generation is a GC
  # root and is never collected; the tradeoff is only that rollback targets
  # older than 7d are gone.
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  # journald defaults to 10% of the filesystem — ~3.7 GB on this 37 GB disk.
  services.journald.extraConfig = "SystemMaxUse=500M";

  system.stateVersion = "24.11";
}
