{ config, pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  home.username = "harry";
  home.homeDirectory = "/home/harry";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # Personal packages
  home.packages = with pkgs; [
    discord
    spotify
  ];

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user.name = "Harry Kruger";
      user.email = "harry@hrry.sh";
    };
  };

  # SSH configuration for GitHub
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/bluescorpian";
        identitiesOnly = true;
        addKeysToAgent = "yes";
      };
    };
  };

  # Personal Mako colors
  services.mako.settings = {
    background-color = "#1e1e2e";
    border-color = "#3e3e60";
  };
}
