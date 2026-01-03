{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Africa/Johannesburg";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_ZA.UTF-8";

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  # I am keeping this enabled for backward compatibility, but mostly using wayland
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  programs.hyprland.enable = true;
  #  hint electron apps to use wayland:
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # NVIDIA
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;   # important for Wayland compositors
    nvidiaSettings = true;
    powerManagement.enable = false;
    open = false;
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "dvp";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Shared group for file sharing between users
  users.groups.harry-shared = {};

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.harry = {
    isNormalUser = true;
    description = "Harry Kruger";
    extraGroups = [ "networkmanager" "wheel" "harry-shared" "docker" ];
    packages = with pkgs; [
      kdePackages.kate
      stow
    ];
  };

  users.users.harry-smartstation = {
    isNormalUser = true;
    description = "Harry (Work)";
    extraGroups = [ "networkmanager" "wheel" "harry-shared" "docker" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-wide shell aliases (available to all users)
  environment.shellAliases = {
    rebuild = "sudo nixos-rebuild switch --flake /home/harry/dotfiles/nix#nixos";
    rebuild-test = "sudo nixos-rebuild test --flake /home/harry/dotfiles/nix#nixos";
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    curl
    openssh
    kdePackages.partitionmanager
  ];


  programs.git = {
    enable = true;                # manages ~/.gitconfig for basics
    package = pkgs.gitFull;       # includes extras like credential helpers
    lfs.enable = true;            # Git LFS support
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

#   security.pam.services = {
#     login = {
#       kwallet = {
#         enable = true;
#       };
#     };
#   };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "25.05"; # Did you read the comment?

  # Declaratively set permissions for shared file access
  systemd.tmpfiles.rules = [
    # Make home directories group-readable (755 = rwxr-xr-x)
    "z /home/harry 0755 harry harry-shared -"
    "z /home/harry-smartstation 0755 harry-smartstation harry-shared -"

    # Create shared directory with setgid bit (2775 = rwxrwsr-x)
    # The setgid bit ensures new files inherit the harry-shared group
    "d /home/shared 2775 harry harry-shared -"
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://claude-code.cachix.org" ];
    trusted-public-keys = [ "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk=" ];
  };

}
