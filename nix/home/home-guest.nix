{ config, pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  home.username = "guest";
  home.homeDirectory = "/home/guest";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
