{ config, pkgs, lib, ... }:

{
  imports = [
    ./common.nix
    ./sway.nix
    ./thunar.nix
  ];

  home.username = "harry";
  home.homeDirectory = "/home/harry";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # Personal packages
  home.packages = with pkgs; [
    osu-lazer-bin
    qbittorrent
    # handbrake  # broken on 2026-07-11 nixpkgs: its bundled ffmpeg-full 8.1.2
    # fails to apply A01-mov-read-name-track-tag patch. Fix PR NixOS/nixpkgs#541043
    # (handbrake 1.11.2) still open. Re-enable once it lands. Issue #540400.
    # makemkv  # temporarily dropped 2026-07-25: upstream download server
    # returns HTTP 525 (Cloudflare SSL handshake fail) so the 1.18.4 src
    # tarball can't be fetched. Re-enable once MakeMKV's host recovers.
  ];

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user.name = "Harry Kruger";
      user.email = "harry@hrry.sh";
      safe.directory = "/home/shared/dotfiles";
    };
  };

  # SSH: VPS access (personal only)
  programs.ssh.settings."vps" = {
    HostName = "91.98.21.137";
    User = "harry";
    IdentityFile = "~/.ssh/bluescorpian";
    IdentitiesOnly = true;
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
}
