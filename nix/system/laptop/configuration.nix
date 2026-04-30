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
}
