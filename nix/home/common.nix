{ config, pkgs, pkgs-stable, worktrunk-pkg, lib, ... }:

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
    gh
    jq
    ripgrep
    fd
    zellij
    worktrunk-pkg  # git worktree manager (wt CLI)

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

    # Authentication
    kdePackages.ksshaskpass  # GUI password prompt for sudo -A / ssh-add

    # LSP servers
    typescript-language-server
    # vscode-langservers-extracted
    # nil  # Nix LSP
  ];

  # Route sudo -A / ssh-add password prompts through a GUI dialog so
  # non-interactive shells (like Claude Code) can drive sudo while you type
  # the password into a Qt window. Run commands with `sudo -A <cmd>`.
  home.sessionVariables = {
    SUDO_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

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
    initExtra = ''
      if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
    '';
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

  # Konsole: custom keytab based on upstream's default with Shift+Enter
  # remapped to ESC+CR, so Claude Code (and similar TUIs reading \r) can
  # insert newlines without submitting. Konsole keytabs replace rather than
  # extend default.keytab, so the full ruleset lives alongside this file —
  # see ./konsole.keytab.
  xdg.dataFile."konsole/konsole.keytab".source = ./konsole.keytab;

  programs.konsole = {
    enable = true;
    defaultProfile = "Konsole";
    profiles.Konsole = {
      name = "Konsole";
      extraConfig = {
        "Keyboard"."KeyBindings" = "konsole";
      };
    };
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

  # Shared agent configuration
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;  # sadjow overlay; nixpkgs claude-code lags upstream
    context = ../../agents/AGENTS.md;
    skills = ../../claude/skills;
    settings = lib.recursiveUpdate
      (builtins.fromJSON (builtins.readFile ../../claude/settings.json))
      {
        hooks.Notification = [{
          matcher = "";
          hooks = [{
            type = "command";
            command = "${config.home.homeDirectory}/.claude/hooks/notify.sh";
          }];
        }];
      };
  };
  # No structured option for statusLine script; module mkMerges home.file so this composes.
  home.file.".claude/statusline.sh" = {
    source = ../../claude/statusline.sh;
    executable = true;
  };
  home.file.".claude/hooks/notify.sh" = {
    source = ../../claude/hooks/notify.sh;
    executable = true;
  };
  home.file.".codex/AGENTS.md".source = ../../agents/AGENTS.md;
  home.file.".codex/config.toml".source = ../../codex/config.toml;
  home.file.".codex/rules".source = ../../codex/rules;
  home.file.".codex/skills".source = ../../codex/skills;

  # Global gitignore
  programs.git.ignores = [
    ".codex"
    "docs/session-notes/"
  ];

  # PipeWire EQ Configuration
  xdg.configFile."pipewire/pipewire.conf.d/10-filter-chain.conf".source = ./pipewire-eq.conf;
}
