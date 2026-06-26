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

  # Thunar file manager (program + supporting services) lives in
  # system/thunar.nix; per-user Thunar config lives in home/thunar.nix.

  # Hint electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Force KWin triple buffering on Wayland. Reduces frame-pacing stalls on
  # AMD iGPU (menus, window open/close, focus switches) where double-buffer
  # latency causes visible hitches.
  environment.sessionVariables.KWIN_TRIPLE_BUFFER = "1";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "dvp";
  };

  # Enable CUPS to print documents
  services.printing = {
    enable = true;
    drivers = [ pkgs.epson_201207w ];
  };

  # SMB client support for network printer shared via Samba
  services.samba-wsdd.enable = true;

  # Network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

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

  # logseq still ships Electron 39, now flagged EOL upstream. Permit it explicitly so the
  # build evaluates. (bitwarden-desktop / claude-desktop also used this and are commented out
  # by choice, not necessity.) Remove once logseq moves to a supported Electron.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # System-wide shell aliases (available to all users)
  # Auto-detects hostname to select the correct configuration (desktop or laptop)
  environment.shellAliases = {
    cc = "claude";
    ccfast = "claude --model sonnet --effort low";
    rebuild = "sudo nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)";
    rebuild-test = "sudo nixos-rebuild test --flake /home/shared/dotfiles/nix#$(hostname)";
    rebuild-vps = "nixos-rebuild switch --flake /home/shared/dotfiles/nix#vps --target-host harry@91.98.21.137 --sudo";
    update-claude = "nix flake update claude-code --flake /home/shared/dotfiles/nix && sudo nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)";
    copy-dotfiles-vps = "rsync -avz --delete --exclude='.*' /home/shared/dotfiles/ harry@91.98.21.137:/home/harry/dotfiles/";
  };

  environment.interactiveShellInit = ''
    ccgo() { claude --permission-mode auto --model sonnet "$*"; }
  '';

  # System packages
  environment.systemPackages = with pkgs; [
    wget
    curl
    openssh
    samba  # SMB client for CUPS network printing
    kdePackages.partitionmanager
    qt6.qtmultimedia
    # claude-desktop  # dropped 2026-06-08 by choice (Electron-39 app). electron-39.8.10 is
    #                   permitted above for logseq, so re-enable = uncomment.
  ];

  services.flatpak.enable = true;

  # Font configuration - enables font dir for Flatpak access
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
  ];

  # Git configuration
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs.enable = true;
    config = {
      init.defaultBranch = "main";
      core.editor = "nano";
      safe.directory = "/home/shared/dotfiles";
    };
  };

  # nix-ld: run unpatched, foreign (non-Nix) dynamic binaries — VS Code
  # extensions, pip/npm-fetched tools, prebuilt SDKs. Keep `libraries` minimal;
  # only add a lib here when a binary actually fails at runtime on it.
  programs.nix-ld.enable = true;

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

  # Open SSH and VNC ports in firewall
  networking.firewall = {
    allowedTCPPorts = [ 22 5900 7000 ]; # 7000: TallyBot sidecar (device TCP)
    allowedUDPPorts = [ 7001 ]; # 7001: TallyBot discovery (TALLY_FIND)
    # KDE Connect ports (TCP and UDP 1714-1764)
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
  };

  # Declaratively set permissions for shared file access
  systemd.tmpfiles.rules = [
    # Create shared directory with setgid bit (2775 = rwxrwsr-x)
    "d /home/shared 2775 harry harry-shared -"
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://claude-code.cachix.org"
      "https://walker.cachix.org"
      "https://walker-git.cachix.org"
    ];
    trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
    ];
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "25.05";
}
