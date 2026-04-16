{ config, pkgs, pkgs-stable, lib, ... }:

{
  # Development packages
  home.packages = with pkgs; [
    # Fonts
    cascadia-code
    pkgs-stable.jetbrains-mono

    # Browsers
    brave
    google-chrome

    # Communication
    discord
    bitwarden-desktop
    thunderbird

    # Media & Creative
    spotify
    haruna
    obs-studio
    gimp
    vlc

    # Office & Productivity
    libreoffice-fresh
    obsidian
    logseq
    keepassxc
    pkgs-stable.super-productivity  # Using stable version due to build issues in unstable

    # Development - Editors
    neovim
    antigravity

    # Development - Languages & Runtimes
    nodejs_22  # Node.js 22.x LTS
    bun
    pnpm
    yarn
    python3

    # Development - Tools
    aichat
    claude-code
    aichat
    gh
    jq
    ripgrep
    fd
    zellij

    # Notifications
    libnotify  # provides notify-send for desktop notifications

    # Database
    mongosh
    mongodb-tools
    mongodb-compass

    # Media Processing
    imagemagick
    ffmpeg

    # Remote Access
    kdePackages.krfb  # KDE VNC server
    kdePackages.krdc  # KDE RDP/VNC client
    remmina  # VNC/RDP client for remote desktop access

    # LSP servers
    typescript-language-server
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

  # Bash configuration - required for Home Manager to modify .bashrc
  programs.bash = {
    enable = true;
    shellAliases = {
      codex = "nix run github:sadjow/codex-cli-nix --";
    };
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

  # KDE Connect for phone integration
  services.kdeconnect = {
    enable = true;
    indicator = true;  # Show indicator in system tray
  };

  # VS Code with extensions
  programs.vscode = {
    enable = true;
    # Force Electron onto the AMD iGPU via DRI_PRIME=0 + Mesa.
    # Without this, VS Code picks the NVIDIA dGPU, which causes texture atlas
    # corruption in the integrated terminal when an external display is connected
    # with fractional scaling (Electron/Chromium GPU process mismatch on PRIME).
    # home-manager reads .pname to look up the VS Code variant in its
    # knownProducts table; symlinkJoin produces no pname by default, causing
    # evaluation to fail. Use `//` to attach the original pname to the wrapper.
    package = (pkgs.symlinkJoin {
      name = "vscode-fhs-igpu";
      paths = [ pkgs.vscode-fhs ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/code \
          --set DRI_PRIME 0 \
          --set __NV_PRIME_RENDER_OFFLOAD 0 \
          --set __GLX_VENDOR_LIBRARY_NAME mesa
      '';
    }) // { pname = pkgs.vscode-fhs.pname; };
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
  # services.mako = {
  #   enable = true;
  #   settings = {
  #     font = "Inter 11";
  #     default-timeout = 5000;
  #     border-radius = 8;
  #     text-color = "#cdd6f4";
  #   };
  # };

  # Polkit agent for authentication
  # services.hyprpolkitagent.enable = true;

  # SSH agent configuration
  services.ssh-agent = {
    enable = true;
  };

  # SSH configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/bluescorpian";
        identitiesOnly = true;
        addKeysToAgent = "yes";
      };
    };
  };
  home.file.".ssh/config".force = true;

  # Fix SSH config ownership: vscode-fhs chroot sees Nix store files (uid 0) as
  # uid 65534 (nobody), causing SSH to reject the symlinked config as bad owner.
  # Solution: force overwrite so home-manager can replace stale regular files,
  # then copy the symlink target to a real file owned by the user.
  home.activation.fixSshConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    if [ -L "$HOME/.ssh/config" ]; then
      _target=$(readlink -f "$HOME/.ssh/config")
      rm "$HOME/.ssh/config"
      install -m600 "$_target" "$HOME/.ssh/config"
    fi
    [ -d "$HOME/.ssh" ] && chmod 700 "$HOME/.ssh"
  '';

  # Claude Code configuration
  home.file.".claude/CLAUDE.md".source = ../../claude/CLAUDE.md;
  home.file.".claude/skills".source = ../../claude/skills;

  # Global gitignore
  programs.git.ignores = [ "docs/session-notes/" ];

  # PipeWire EQ Configuration
  xdg.configFile."pipewire/pipewire.conf.d/10-filter-chain.conf".source = ./pipewire-eq.conf;
}
