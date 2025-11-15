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
    userName = "Harry Kruger";
    userEmail = "harry@hrry.sh";
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
}
