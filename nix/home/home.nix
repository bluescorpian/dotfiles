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
  # services.mako.settings = {
  #   background-color = "#1e1e2e";
  #   border-color = "#3e3e60";
  # };

  # Custom desktop entry for Brave with default profile
  xdg.desktopEntries.brave-browser = {
    name = "Brave Web Browser";
    genericName = "Web Browser";
    exec = "brave --profile-directory=Default %U";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "application/pdf"
      "application/rdf+xml"
      "application/rss+xml"
      "application/xhtml+xml"
      "application/xhtml_xml"
      "application/xml"
      "image/gif"
      "image/jpeg"
      "image/png"
      "image/webp"
      "text/html"
      "text/xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    icon = "brave-browser";
  };

  # Override Hyprland keybinding to use default profile
  # wayland.windowManager.hyprland.settings = {
  #   bind = [
  #     "$mod, B, exec, brave --profile-directory=Default"
  #   ];
  # };
}
