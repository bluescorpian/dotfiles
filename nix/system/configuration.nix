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
  hardware.nvidia.open = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "dvp";
  };

  services.xserver = {
    layout = "us";
    xkbVariant = "dvp";
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.harry = {
    isNormalUser = true;
    description = "Harry Kruger";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
      keepassxc
      stow
      brave
    #  thunderbird
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    curl
    openssh
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

  security.pam.services = {
    login = {
      kwallet = {
        enable = true;
      };
    };
  };

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


  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://claude-code.cachix.org" ];
    trusted-public-keys = [ "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk=" ];
  };

  boot.loader.grub.configurationLimit = 3;


}
