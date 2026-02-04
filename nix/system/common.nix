{ config, pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;  # Keep only 10 most recent generations in boot menu
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone
  time.timeZone = "Africa/Johannesburg";

  # Select internationalisation properties
  i18n.defaultLocale = "en_ZA.UTF-8";

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Hint electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # XDG Desktop Portal configuration - use KDE as the backend
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common.default = "kde";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "dvp";
  };

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Enable sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Shared group for file sharing between users
  users.groups.harry-shared = {};

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-wide shell aliases (available to all users)
  # Auto-detects hostname to select the correct configuration (desktop or laptop)
  environment.shellAliases = {
    rebuild = "sudo nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)";
    rebuild-test = "sudo nixos-rebuild test --flake /home/shared/dotfiles/nix#$(hostname)";
  };

  # System packages
  environment.systemPackages = with pkgs; [
    wget
    curl
    openssh
    kdePackages.partitionmanager
  ];

  # Git configuration
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs.enable = true;
    config = {
      init.defaultBranch = "main";
      core.editor = "nano";
    };
  };

  # Docker configuration
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # SSH configuration for remote access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";  # Security best practice
      PasswordAuthentication = true;  # Allow password auth (can use SSH keys for password-less login)
    };
  };

  # Open SSH port in firewall
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Declaratively set permissions for shared file access
  systemd.tmpfiles.rules = [
    # Create shared directory with setgid bit (2775 = rwxrwsr-x)
    "d /home/shared 2775 harry harry-shared -"
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://claude-code.cachix.org" ];
    trusted-public-keys = [ "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk=" ];
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "25.05";
}
