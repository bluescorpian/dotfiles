{ config, pkgs, pkgs-stable, worktrunk-pkg, lib, ... }:

let
  # Make HM's read-only Nix-store symlink at $HOME/<target> into a real
  # writable copy on every rebuild. Pair with `home.file.<target>.force = true`
  # (and a source if HM doesn't already provide one). Trade-off: in-place
  # edits to the live file are clobbered on every rebuild.
  writableSymlinkSwap = target: lib.hm.dag.entryAfter ["linkGeneration"] ''
    if [ -L "$HOME/${target}" ]; then
      _t=$(readlink -f "$HOME/${target}")
      rm "$HOME/${target}"
      install -m600 "$_t" "$HOME/${target}"
    fi
  '';
in
{
  # Development packages
  home.packages = with pkgs; [
    # Fonts
    cascadia-code
    nerd-fonts.jetbrains-mono

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
    #
    # Keyring backend (FHS quirk): vscode-fhs's bubblewrap rootfs does not
    # bundle libsecret, so Electron's --password-store=gnome-libsecret backend
    # fails to dlopen and falls back to "basic" with an "OS keyring is not
    # available for encryption" banner. The kwallet{5,6} backends use raw
    # D-Bus via libdbus (which IS in the FHS) and reach kwalletd6 directly
    # under both KDE and sway — no extra libs needed, same kdewallet file as
    # Brave's --password-store=kwallet5. If a host hits that banner, fix it
    # per-host with ~/.vscode/argv.json ("password-store": "kwallet6"), or
    # codify globally by adding `--add-flags --password-store=kwallet6` to
    # the wrapProgram call below.
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
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 10;
    };
    themeFile = "Catppuccin-Mocha";
    settings = {
      # Ligatures on, broken under the cursor for readability
      disable_ligatures = "cursor";

      # Window chrome
      hide_window_decorations = "yes";
      window_padding_width = 8;
      background_opacity = "0.92";
      background_blur = 32;
      confirm_os_window_close = 0;

      # Tab bar
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_title_template = "{index}: {title}";

      # Scrollback & clipboard
      scrollback_lines = 100000;
      copy_on_select = "clipboard";

      # Bell & mouse
      enable_audio_bell = "no";
      mouse_hide_wait = "2.0";

      # Cursor trail (kitty 0.36+)
      cursor_trail = 3;
      cursor_blink_interval = "0.5";
    };
    keybindings = {
      "ctrl+equal"       = "change_font_size all +1.0";
      "ctrl+minus"       = "change_font_size all -1.0";
      "ctrl+0"           = "change_font_size all 0";
      "ctrl+shift+enter" = "new_window_with_cwd";
      "ctrl+shift+t"     = "new_tab_with_cwd";
      "ctrl+shift+n"     = "new_os_window_with_cwd";
      "alt+left"         = "neighboring_window left";
      "alt+right"        = "neighboring_window right";
      "alt+up"           = "neighboring_window up";
      "alt+down"         = "neighboring_window down";
      "ctrl+shift+e"     = "open_url_with_hints";
    };
  };
  # Rofi — launcher, window switcher, and dmenu replacement. As of rofi 2.0
  # (Aug 2025) it has native Wayland support, so a single binary replaces
  # what was previously wofi+swayr on this machine. Themed to match the
  # Catppuccin Mocha palette used in waybar and mako.
  programs.rofi = {
    enable = true;
    font = "JetBrainsMono Nerd Font 11";
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      icon-theme = "Adwaita";
      display-drun = "Apps";
      display-run = "Run";
      display-window = "Windows";
      drun-display-format = "{name}";
      window-format = "{w} · {c} · {t}";
      sidebar-mode = false;
    };
    # The theme file is installed via xdg.configFile below and referenced
    # by name here — passing a derivation directly to `theme` confuses the
    # HM module (it tries to render it as a rasi attrset).
    theme = "catppuccin-mocha";
  };

  xdg.configFile."rofi/themes/catppuccin-mocha.rasi".text = ''
    * {
      bg:        #1e1e2e;
      bg-alt:    #313244;
      bg-sel:    #45475a;
      fg:        #cdd6f4;
      fg-dim:    #a6adc8;
      accent:    #89b4fa;
      urgent:    #f38ba8;
      active:    #a6e3a1;

      background-color: transparent;
      text-color:       @fg;
    }

    window {
      width:            640px;
      background-color: @bg;
      border:           2px;
      border-color:     @accent;
      border-radius:    0;
      padding:          14px;
    }

    mainbox {
      children: [ inputbar, message, listview ];
      spacing:  10px;
    }

    inputbar {
      children:         [ prompt, entry ];
      spacing:          8px;
      padding:          6px 10px;
      background-color: @bg-alt;
      border-radius:    0;
    }

    prompt {
      text-color: @accent;
    }

    entry {
      placeholder:       "type to filter";
      placeholder-color: @fg-dim;
    }

    message {
      background-color: @bg-alt;
      border-radius:    0;
      padding:          6px 10px;
    }
    textbox {
      text-color: @fg;
    }

    listview {
      lines:        10;
      columns:      1;
      scrollbar:    false;
      spacing:      2px;
      fixed-height: true;
    }

    element {
      padding:       6px 8px;
      spacing:       8px;
      border-radius: 0;
    }
    element normal.normal   { text-color: @fg; }
    element normal.urgent   { text-color: @urgent; }
    element normal.active   { text-color: @active; }
    element selected.normal { background-color: @accent; text-color: @bg; }
    element selected.urgent { background-color: @urgent; text-color: @bg; }
    element selected.active { background-color: @active; text-color: @bg; }

    element-icon {
      size:             1.2em;
      background-color: transparent;
    }
    element-text {
      background-color: transparent;
      text-color:       inherit;
      vertical-align:   0.5;
    }
  '';

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
  # SSH config needs to be a real file (not a Nix-store symlink) because
  # vscode-fhs chroot sees store files (uid 0) as uid 65534 (nobody) and
  # SSH then rejects the config as bad owner.
  home.file.".ssh/config".force = true;
  home.activation.fixSshConfig = writableSymlinkSwap ".ssh/config";
  home.activation.fixSshDirMode = lib.hm.dag.entryAfter ["linkGeneration"] ''
    [ -d "$HOME/.ssh" ] && chmod 700 "$HOME/.ssh"
  '';

  # Shared agent configuration. The module's `settings` option targets
  # ~/.claude/settings.json, which Claude's own /config command writes to —
  # a Nix-store symlink would be read-only and /config would fail. Claude
  # only loads settings.local.json at the *project* level, not at user
  # level, so that's not a workaround either. Pattern: declare the file
  # normally with `force = true`, then in an activation script after
  # linkGeneration swap the symlink for a real writable copy. Same
  # approach as ~/.ssh/config above. Trade-off: /config edits are clobbered
  # on every rebuild — commit them back to the repo to make them stick.
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;  # sadjow overlay; nixpkgs claude-code lags upstream
    context = ../../agents/AGENTS.md;
    skills = ../../claude/skills;
  };
  home.file.".claude/settings.json" = {
    source = ../../claude/settings.json;
    force = true;
  };
  home.activation.makeClaudeSettingsWritable = writableSymlinkSwap ".claude/settings.json";
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
