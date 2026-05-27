{ config, pkgs, lib, ... }:

{
  imports = [
    ./common.nix
    ./sway.nix
  ];

  home.username = "harry-smartstation";
  home.homeDirectory = "/home/harry-smartstation";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # Work packages (minimal, focused on productivity)
  home.packages = with pkgs; [
    anydesk
  ];

  # Force Brave to use KWallet for passwords regardless of session.
  # Plasma auto-detects KDE → kwallet5; sway sets XDG_CURRENT_DESKTOP=sway →
  # falls back to the "basic" store, so saved logins look missing. Pinning the
  # flag here makes both sessions share the same kdewallet entries ("Brave
  # Safe Storage"). Note: the nixpkgs brave wrapper does NOT read
  # brave-flags.conf, so the flag must live in the launcher itself.
  xdg.desktopEntries.brave-browser = {
    name = "Brave Web Browser";
    genericName = "Web Browser";
    exec = "brave --password-store=kwallet5 %U";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "application/pdf"
      "application/xhtml+xml"
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
  home.shellAliases.brave = "brave --password-store=kwallet5";

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user.name = "Harry Kruger";
      user.email = "harry@hrry.sh";  # Or use work email if different
      safe.directory = "/home/shared/dotfiles";
      pull.rebase = false;
    };
  };
}
