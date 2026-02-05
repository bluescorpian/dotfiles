{ config, pkgs, ... }:

{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  # Hostname
  networking.hostName = "desktop";

  # NVIDIA configuration
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;   # important for Wayland compositors
    nvidiaSettings = true;
    powerManagement.enable = false;
    open = false;
  };

  # Blacklist ucsi_ccg module to prevent i2c timeout errors that cause login freezes
  # This module is for USB-C functionality on the GPU and commonly causes issues
  boot.blacklistedKernelModules = [ "ucsi_ccg" ];

  # User accounts - desktop has both personal and work users
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
}
