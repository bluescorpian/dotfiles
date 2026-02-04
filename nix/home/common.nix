{ config, pkgs, pkgs-stable, ... }:

{
  # Development packages
  home.packages = with pkgs; [
    # Fonts
    cascadia-code
    jetbrains-mono

    # Editors
    vscode
    neovim

    # Browsers
    brave
    google-chrome

    # Node.js ecosystem
    nodejs_22  # Node.js 22.x LTS
    bun
    nodePackages.pnpm
    nodePackages.yarn

    # Development utilities
    jq
    ripgrep
    fd
    zellij
    claude-code
    codex

    # Utilities
    imagemagick
    ffmpeg

    # MongoDB tools
    mongosh
    mongodb-tools
    mongodb-compass

    # Programs
    thunderbird
    keepassxc
    pkgs-stable.super-productivity  # Using stable version due to build issues in unstable
    libreoffice-fresh  # Office suite
    obsidian

    # Remote access
    kdePackages.krfb  # KDE VNC server
    kdePackages.krdc  # KDE RDP/VNC client
    remmina  # VNC/RDP client for remote desktop access

    # LSP servers (commented examples for later)
    # nodePackages.typescript-language-server
    # vscode-langservers-extracted
    # nil  # Nix LSP
  ];

  # Direnv configuration with nix-direnv for automatic environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # Zoxide - smarter cd command that learns your habits
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # Qt configuration
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

  # Terminal and launcher
  programs.kitty.enable = true;
  programs.wofi.enable = true;

  # Hyprland window manager
  # wayland.windowManager.hyprland.enable = true;

  # wayland.windowManager.hyprland.settings = {
  #   "$mod" = "SUPER";
  #   bind =
  #     [
  #       "$mod, B, exec, brave"
  #       "$mod, RETURN, exec, kitty"
  #       "$mod, K, exec, kate"
  #       # Close focused window
  #       "$mod, Q, killactive,"

  #       # Quit Hyprland session
  #       "$mod SHIFT, Q, exit,"
  #         "$mod, D, exec, wofi --show drun"
  #     ]
  #     ++ (
  #       # workspaces
  #       # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
  #       builtins.concatLists (builtins.genList (i:
  #           let ws = i + 1;
  #           in [
  #             "$mod, code:1${toString i}, workspace, ${toString ws}"
  #             "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
  #           ]
  #         )
  #         9)
  #     );
  #     input = {
  #       kb_layout = "us";
  #       kb_variant = "dvp";
  #     };
  # };

  # Notification daemon
  services.mako = {
    enable = true;
    settings = {
      font = "Inter 11";
      default-timeout = 5000;
      border-radius = 8;
      text-color = "#cdd6f4";
    };
  };

  # Polkit agent for authentication
  # services.hyprpolkitagent.enable = true;

  # SSH agent configuration
  services.ssh-agent = {
    enable = true;
  };

  # PipeWire EQ Configuration
  xdg.configFile."pipewire/pipewire.conf.d/10-filter-chain.conf".source = ./pipewire-eq.conf;
}
