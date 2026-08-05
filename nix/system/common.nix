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

  # NOTE: no permittedInsecurePackages needed. logseq is pinned to 0.10.14 (Electron
  # 38.7.1, not flagged insecure) via the nixpkgs-logseq input — see flake.nix. If you
  # re-enable bitwarden-desktop / claude-desktop (Electron-39 apps), add back:
  #   nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # System-wide shell aliases (available to all users)
  # Auto-detects hostname to select the correct configuration (desktop or laptop)
  environment.shellAliases = {
    cc = "claude";
    ccfast = "claude --model sonnet --effort low";
    rebuild = "sudo nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)";
    rebuild-test = "sudo nixos-rebuild test --flake /home/shared/dotfiles/nix#$(hostname)";
    rebuild-boot = "sudo nixos-rebuild boot --flake /home/shared/dotfiles/nix#$(hostname)";
    # Target the `vps` ssh alias, not the raw IP: ~/.ssh/config pins a non-default
    # key (IdentitiesOnly + IdentityFile), so connecting by IP fails publickey auth.
    # `--use-remote-sudo` despite its deprecation notice: with `--flake`, nixos-rebuild
    # re-execs into the nixos-rebuild built by the *target's* flake output (24.11), which
    # predates the `--elevate=sudo`/`--sudo` spelling its own deprecation notice suggests.
    # `--use-substitutes` makes the VPS pull cacheable paths from cache.nixos.org itself
    # instead of streaming them over this uplink. Measured on the hermes deploy: 7.68 of
    # 8.74 GiB was on cache.nixos.org, so this is the difference between ~70 min and
    # ~10 min of upload. Only locally-built paths (hermes + its uv2nix wheels) still ship
    # from here.
    rebuild-vps = "nixos-rebuild switch --flake /home/shared/dotfiles/nix#vps --target-host vps --use-remote-sudo --use-substitutes";
    update-claude = "/home/shared/dotfiles/scripts/flake-autoupdate.sh claude-code";
    flake-autoupdate = "/home/shared/dotfiles/scripts/flake-autoupdate.sh";
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
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
      { from = 3000; to = 3100; } # local dev servers, reachable from LAN
    ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
  };

  # Declaratively set permissions for shared file access
  systemd.tmpfiles.rules = [
    # Create shared directory with setgid bit (2775 = rwxrwsr-x)
    "d /home/shared 2775 harry harry-shared -"
    # Tools that hardcode the FHS Chrome install path (e.g. the Playwright MCP
    # plugin's default browser lookup) can't find NixOS's nix-store binary.
    # Recreate the expected /opt/google/chrome/chrome symlink on every boot.
    "d /opt/google/chrome 0755 root root -"
    "L+ /opt/google/chrome/chrome - - - - ${pkgs.google-chrome}/bin/google-chrome-stable"
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
