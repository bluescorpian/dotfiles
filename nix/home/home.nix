{ config, pkgs, ... }:

{
  home.username = "harry";
  home.homeDirectory = "/home/harry";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    discord
    google-chrome
  ];
}
