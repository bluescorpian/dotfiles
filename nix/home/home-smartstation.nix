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
  ];

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


  # OpenClaw AI gateway — webchat at http://127.0.0.1:18789
  # Token is stored in /run/agenix/openclaw (managed by agenix, not committed)
  programs.openclaw = {
    enable = true;
    config.gateway.mode = "local";
  };
  xdg.configFile."systemd/user/openclaw-gateway.service.d/token.conf".text = ''
    [Service]
    EnvironmentFile=/run/agenix/openclaw
  '';

  # Override Mako colors for visual distinction from personal account
  # services.mako.settings = {
  #   background-color = "#2e2e3e";
  #   border-color = "#4e4e70";
  # };
}
