{ config, pkgs, ... }:

{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  # Hostname
  networking.hostName = "laptop";

  services.asusd.enable = true;

  # Graphics - NVIDIA RTX A1000 with AMD integrated graphics
  hardware.graphics.enable = true;

  # NVIDIA drivers
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Use open-source kernel modules (Ampere/RTX A1000 supports this)
    open = true;

    # Enable modesetting (required for Wayland/Hyprland)
    modesetting.enable = true;

    # Power management (helps with battery life)
    # finegrained=false: with finegrained=true, the dGPU suspends after every
    # offloaded client exits and any subsequent GLX/Vulkan probe (including
    # incidental ones from KWin/Electron) blocks for tens of ms while the
    # bus link retrains. Turning it off keeps the dGPU in a low D3 state
    # without the per-client suspend/resume cycle that causes UI stutter.
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # PRIME offload mode for hybrid graphics (best battery life)
    # Use integrated AMD GPU by default, NVIDIA only when needed
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;  # Provides nvidia-offload command
      };

      # PCI Bus IDs
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  boot.kernelParams = [
    "acpi_backlight=native"
    # Disable AMD PSR (Panel Self Refresh) on the iGPU. PSR causes visible
    # UI stutter on Rembrandt/Phoenix when the panel exits self-refresh
    # (opening menus, focus changes, new windows).
    "amdgpu.dcdebugmask=0x10"
  ];


  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;  # Auto-power on at boot

  # User accounts - laptop has both personal and work users
  users.users.harry = {
    isNormalUser = true;
    description = "Harry Kruger";
    extraGroups = [ "networkmanager" "wheel" "harry-shared" "docker" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEi+18q1ME2FMbniwQ276WWakX/j8V19fn37l3G7FTGq dsharryh27@gmail.com"
    ];
    packages = with pkgs; [
      kdePackages.kate
      stow
    ];
  };

  users.users.harry-smartstation = {
    isNormalUser = true;
    description = "Harry (Work)";
    extraGroups = [ "networkmanager" "wheel" "harry-shared" "docker" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEi+18q1ME2FMbniwQ276WWakX/j8V19fn37l3G7FTGq dsharryh27@gmail.com"
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  users.users.guest = {
    isNormalUser = true;
    description = "Guest";
    hashedPassword = "$6$bW4BLv3IzUkDrhtK$/hWICa0LZDoeLjN6bh0hDbMhm8YujobvZJyhcWVA5Nqk4ET0VQMbhYf5Xg74X8w9jHof87ppH/QQPGL0fKMMs.";
  };

  # Agenix secrets — openclaw gateway token for harry-smartstation (work user on laptop)
  age.secrets.openclaw = {
    file = ../../secrets/openclaw.age;
    owner = "harry-smartstation";
    mode = "0400";
  };

  # Sway compositor — offered by SDDM as an alternative session to Plasma.
  # User-level config lives in home-manager (home-smartstation.nix).
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      grim
      slurp
      wl-clipboard
      wdisplays
      brightnessctl
      playerctl
    ];
    # The HDMI port is wired to the NVIDIA dGPU, while the internal panel is
    # wired to the AMD iGPU. Expose both DRM cards to wlroots, keeping AMD
    # first so Sway still uses the integrated GPU as the primary device.
    #
    # realpath is mandatory: wlroots splits WLR_DRM_DEVICES on ':', and the
    # by-path symlinks contain colons (pci-0000:05:00.0), so passing those
    # symlinks directly gets parsed as multiple bogus paths. The canonical
    # /dev/dri/cardN targets have no colons.
    extraOptions = [ "--unsupported-gpu" ];
    extraSessionCommands = ''
      export WLR_DRM_DEVICES="$(${pkgs.coreutils}/bin/realpath /dev/dri/by-path/pci-0000:05:00.0-card):$(${pkgs.coreutils}/bin/realpath /dev/dri/by-path/pci-0000:01:00.0-card)"
      # Redirect stdout/stderr to a file before exec'ing sway. The regular
      # SDDM session entry leaves stdout/stderr attached to SDDM's pipe, and
      # something on that pipe (buffer fill? SIGPIPE? closed fd?) causes sway
      # to die silently at startup on this hardware — the debug entry only
      # worked because it explicitly redirected output. Routing through a real
      # file avoids that failure mode and gives us a log either way.
      exec >> "$HOME/sway-session.log" 2>&1
    '';
  };

  # Debug session entry: same as "Sway" but with --debug and output captured
  # to ~/sway-session.log so we can read why sway is dying. Registered as a
  # sessionPackage because SDDM only enumerates session files from packages
  # listed there — files dropped into /etc/xdg/wayland-sessions/ are ignored.
  #
  # The Exec= line points at a single wrapper script: SDDM parses Exec= per
  # the XDG spec where single quotes are not special, so any inline shell
  # pipeline gets split into nonsense args. A standalone script sidesteps
  # that entirely.
  #
  # Drop this whole block once the launch issue is solved.
  services.displayManager.sessionPackages =
    let
      swayDebug = pkgs.writeShellScript "sway-debug" ''
        exec /run/current-system/sw/bin/sway --debug > "$HOME/sway-session.log" 2>&1
      '';
    in [
      (pkgs.writeTextFile {
        name = "sway-debug-session";
        destination = "/share/wayland-sessions/sway-debug.desktop";
        text = ''
          [Desktop Entry]
          Name=Sway (debug)
          Comment=Sway with output captured to ~/sway-session.log
          Exec=${swayDebug}
          Type=Application
        '';
      } // { providedSessions = [ "sway-debug" ]; })
    ];
}
