{ config, pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  home.username = "harry-smartstation";
  home.homeDirectory = "/home/harry-smartstation";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # Work packages (minimal, focused on productivity)
  home.packages = with pkgs; [
    claude-code
    imagemagick
    ffmpeg
  ];

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user.name = "Harry Kruger";
      user.email = "harry@hrry.sh";  # Or use work email if different
    };
  };

  # SSH configuration for GitHub (work key)
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/work-key";
        identitiesOnly = true;
        addKeysToAgent = "yes";
      };
    };
  };

  # Override Mako colors for visual distinction from personal account
  services.mako.settings = {
    background-color = "#2e2e3e";
    border-color = "#4e4e70";
  };
}
