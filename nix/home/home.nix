{ config, pkgs, ... }:

{
  home.username = "harry";
  home.homeDirectory = "/home/harry";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    discord
    google-chrome
    claude-code
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Harry Kruger";
      user.email = "harry@hrry.sh";
    };
  };

#   systemd.user.sessionVariables = config.home-manager.users.justinas.home.sessionVariables;

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  # Enable dark mode for Plasma
  programs.plasma = {
    enable = true;
    workspace.lookAndFeel = "org.kde.breezedark.desktop";
  };

  programs.kitty.enable = true; # required for the default Hyprland config
  programs.wofi.enable = true;

  wayland.windowManager.hyprland.enable = true;

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind =
      [
        "$mod, B, exec, brave"
        "$mod, RETURN, exec, kitty"
        "$mod, K, exec, kate"
        # Close focused window
        "$mod, Q, killactive,"

        # Quit Hyprland session
        "$mod SHIFT, Q, exit,"
          "$mod, D, exec, wofi --show drun"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
        builtins.concatLists (builtins.genList (i:
            let ws = i + 1;
            in [
              "$mod, code:1${toString i}, workspace, ${toString ws}"
              "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          )
          9)
      );
      input = {
        kb_layout = "us";
        kb_variant = "dvp";
      };
  };

  services.mako = {
    enable = true;
    settings = {
      # Basic appearance
      font = "Inter 11";
      default-timeout = 5000;  # in milliseconds
      border-radius = 8;

      # Colours — adapt to your theme
      background-color = "#1e1e2e";
      text-color = "#cdd6f4";
      border-color = "#3e3e60";
    };
  };

  services.hyprpolkitagent.enable = true;

}
