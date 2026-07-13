{ config, pkgs, pkgs-stable, logseq-pkg, worktrunk-pkg, lib, ... }:

let
  playwrightBrowsers = (builtins.fromJSON (builtins.readFile "${pkgs.playwright-driver}/browsers.json")).browsers;
  chromiumRev = (builtins.head (builtins.filter (x: x.name == "chromium") playwrightBrowsers)).revision;
  chromiumBin = "${pkgs.playwright-driver.browsers}/chromium-${chromiumRev}/chrome-linux64/chrome";

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

  # nixpkgs-logseq (see flake.nix) is pinned to Jan 2026, so its Electron/glibc
  # (2.40) has fallen behind main nixpkgs' Mesa (26.1.3, needs glibc >=2.41).
  # On NixOS every app loads GPU drivers from the system-wide /run/opengl-driver
  # regardless of which nixpkgs input built it, so Logseq's GBM/Wayland buffer
  # init now crashes on launch (GLIBC_ABI_GNU2_TLS not found). Forcing X11
  # (XWayland) skips that GBM path entirely and falls back to software
  # compositing, which works. logseq's package.nix has no commandLineArgs
  # override (unlike discord above), so wrap it manually. Drop this wrapper
  # once nixpkgs-logseq is unpinned or the glibc/Mesa versions realign.
  logseq-x11 = pkgs.symlinkJoin {
    name = "logseq-x11";
    paths = [ logseq-pkg ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/logseq
      makeWrapper ${lib.getExe logseq-pkg} $out/bin/logseq --add-flags "--ozone-platform=x11"
    '';
  };
in
{
  # Development packages
  home.packages = with pkgs; [
    (import ../packages/claude-conversation-search { inherit pkgs; })

    # Fonts
    cascadia-code
    nerd-fonts.jetbrains-mono

    # Browsers
    # Pin Brave's keyring backend to kwallet6. Chromium picks its cookie/password
    # encryption store from $XDG_CURRENT_DESKTOP: KDE → kwallet (v11), but sway is
    # unrecognised → silent fallback to the "basic" store (hardcoded key, v10). That
    # mismatch orphaned all v11 cookies on the KDE→sway switch (→ logged out of every
    # site). Forcing kwallet6 keeps one backend across both DEs; same wallet VS Code
    # uses (see kwallet6 note below). v10 entries still read via the built-in fallback.
    (brave.override { commandLineArgs = "--password-store=kwallet6"; })
    google-chrome

    # Communication
    # Fix partial UI flicker (on hover/dropdowns and Sway workspace switches) on
    # NVIDIA + Wayland. The compositor stack already supports explicit sync
    # (sway 1.11/wlroots 0.19, NVIDIA 595), but NVIDIA's driver never handled
    # *implicit* DMABUF sync — so a client that doesn't negotiate explicit sync
    # races the compositor and shows regional corruption on repaint. Discord
    # bundles Electron 37 / Chrome 138, which HAS the explicit-sync feature but
    # leaves it off by default; this flag turns it on. (Chromium merges multiple
    # --enable-features, so this is additive to the wrapper's WaylandWindowDecorations.)
    (discord.override { commandLineArgs = "--enable-features=WaylandLinuxDrmSyncobj"; })
    # bitwarden-desktop  # dropped 2026-06-08 by choice (Electron-39 app). electron-39.8.10 is
    #                      permitted in system/common.nix for logseq, so re-enable = uncomment.
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
    logseq-x11  # pinned to 0.10.14 via nixpkgs-logseq input (see flake.nix); wrapped for --ozone-platform=x11 (see logseq-x11 above)
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
    go

    # Development - Tools
    playwright-driver.browsers
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
    # mongodb-compass  # broken as of the 2026-07-11 nixpkgs bump: wrapGAppsHook
    # fails with "bad array subscript" during patchelf. Re-add once fixed upstream.

    # Media Processing
    imagemagick
    ffmpeg
    sox  # audio recording/processing; required by Claude Code voice mode

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
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_LAUNCH_OPTIONS_EXECUTABLE_PATH = chromiumBin;
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
      # home-manager made profiles.<name>.font.name a required option (no
      # default); match the JetBrainsMono Nerd Font used across sway/waybar/rofi.
      font.name = "JetBrainsMono Nerd Font";
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
    # Brave's --password-store=kwallet6. Codified globally below via --add-flags
    # so both hosts get it from the repo; supersedes any per-host
    # ~/.vscode/argv.json ("password-store": "kwallet6") workaround.
    package = (pkgs.symlinkJoin {
      name = "vscode-fhs-igpu";
      paths = [ pkgs.vscode-fhs ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/code \
          --add-flags "--password-store=kwallet6" \
          --set DRI_PRIME 0 \
          --set __NV_PRIME_RENDER_OFFLOAD 0 \
          --set __GLX_VENDOR_LIBRARY_NAME mesa
      '';
    }) // { pname = pkgs.vscode-fhs.pname; meta.mainProgram = "code"; };
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

      # TEMPORARY: kitty 0.47.1 bug — config watcher exhausts inotify watches on NixOS/HM
      # symlink layout (upstream #10104, fixed in 0.47.2). Negative value disables watcher.
      # Remove after `nix flake update` picks up 0.47.2 from nixos-unstable.
      auto_reload_config = -1;
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
  # Catppuccin Mocha palette used in waybar and mako, and styled to mirror
  # the Walker launcher below (rounded card, 10px rows, soft translucent
  # accent selection) so the two launchers feel like one family.
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
      sel-bg:    rgba(137, 180, 250, 0.25);   /* alpha(accent, 0.25) — matches walker */
      urgent:    #f38ba8;
      active:    #a6e3a1;

      background-color: transparent;
      text-color:       @fg;
    }

    /* Note: rofi rasi has no box-shadow, so walker's drop-shadow elevation
       can't be reproduced — the rounded card + accent border carry the look. */
    window {
      width:            500px;
      background-color: @bg;
      border:           2px;
      border-color:     @accent;
      border-radius:    20px;       /* walker .box-wrapper: 20px */
      padding:          20px;       /* walker: 20px */
    }

    mainbox {
      children: [ inputbar, message, listview ];
      spacing:  12px;
    }

    inputbar {
      children:         [ prompt, entry ];
      spacing:          8px;
      padding:          10px;       /* walker .input: 10px */
      background-color: @bg-alt;
      border-radius:    10px;       /* walker .search-container: 10px */
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
      border-radius:    10px;
      padding:          10px;
    }
    textbox {
      text-color: @fg;
    }

    listview {
      lines:        8;
      columns:      1;
      scrollbar:    false;
      spacing:      2px;
      fixed-height: true;
    }

    element {
      /* walker uses 10px all round, but its rows carry an icon + two text
         lines; these single-line dmenu rows look too airy at 10px vertical,
         so tighten the vertical padding while keeping the horizontal room. */
      padding:       4px 12px;
      spacing:       10px;
      border-radius: 8px;
    }
    element normal.normal   { text-color: @fg; }
    element normal.urgent   { text-color: @urgent; }
    element normal.active   { text-color: @active; }
    /* Soft translucent pill + light text (walker: alpha(accent, 0.25)) */
    element selected.normal { background-color: @sel-bg; text-color: @fg; }
    element selected.urgent { background-color: @sel-bg; text-color: @urgent; }
    element selected.active { background-color: @sel-bg; text-color: @active; }

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

  # Walker — unified launcher (apps + files in one popup). Replaces rofi-drun
  # for the main $mod+d bind; rofi stays for window/workspace/clipboard pickers.
  programs.walker = {
    enable = true;
    runAsService = true;
    config = {
      theme = "catppuccin-mocha";
      providers.default = [ "desktopapplications" "calc" ];
      providers.empty   = [ "desktopapplications" ];
      providers.prefixes = [
        { provider = "files";     prefix = "/"; }
        { provider = "runner";    prefix = ">"; }
        { provider = "websearch"; prefix = "@"; }
        { provider = "windows";   prefix = "$"; }
        { provider = "calc";      prefix = "="; }
      ];
      close_when_open = true;
      click_to_close  = true;
      # Grab the keyboard the moment the popup opens (Exclusive layer-shell
      # keyboard mode). Without this walker defaults to OnDemand, which only
      # takes focus once the pointer enters the surface — hence having to
      # mouse over it before you can type.
      force_keyboard_focus = true;
    };

    # Selecting a custom theme REPLACES walker's default style.css entirely —
    # it does not inherit — so this is the upstream v2.16 default stylesheet
    # recolored to Catppuccin Mocha. Structure/spacing are untouched; only the
    # palette changes. Accent #89b4fa (blue) matches the rofi/waybar/mako theme.
    themes."catppuccin-mocha".style = ''
      @define-color window_bg_color #1e1e2e;
      @define-color accent_bg_color #89b4fa;
      @define-color theme_fg_color #cdd6f4;
      @define-color error_bg_color #f38ba8;
      @define-color error_fg_color #1e1e2e;

      * {
        all: unset;
      }

      popover {
        background: #313244;
        border: 1px solid #313244;
        border-radius: 18px;
        padding: 10px;
      }

      .normal-icons {
        -gtk-icon-size: 16px;
      }

      .large-icons {
        -gtk-icon-size: 32px;
      }

      scrollbar {
        opacity: 0;
      }

      .box-wrapper {
        box-shadow:
          0 19px 38px rgba(0, 0, 0, 0.3),
          0 15px 12px rgba(0, 0, 0, 0.22);
        background: @window_bg_color;
        padding: 20px;
        border-radius: 20px;
        border: 2px solid @accent_bg_color;
      }

      .preview-box,
      .elephant-hint,
      .placeholder {
        color: @theme_fg_color;
      }

      .search-container {
        border-radius: 10px;
      }

      .input placeholder {
        opacity: 0.5;
      }

      .input selection {
        background: #45475a;
      }

      .input {
        caret-color: @theme_fg_color;
        background: #313244;
        padding: 10px;
        color: @theme_fg_color;
      }

      .list {
        color: @theme_fg_color;
      }

      .item-box {
        border-radius: 10px;
        padding: 10px;
      }

      .item-quick-activation {
        background: alpha(@accent_bg_color, 0.25);
        border-radius: 5px;
        padding: 10px;
      }

      child:selected .item-box,
      row:selected .item-box {
        background: alpha(@accent_bg_color, 0.25);
      }

      .item-subtext {
        font-size: 12px;
        opacity: 0.5;
      }

      .providerlist .item-subtext {
        font-size: unset;
        opacity: 0.75;
      }

      .item-image-text {
        font-size: 28px;
      }

      .preview {
        border: 1px solid alpha(@accent_bg_color, 0.25);
        border-radius: 10px;
        color: @theme_fg_color;
      }

      .calc .item-text {
        font-size: 24px;
      }

      .symbols .item-image {
        font-size: 24px;
      }

      .todo.done .item-text-box {
        opacity: 0.25;
      }

      .todo.urgent {
        font-size: 24px;
      }

      .todo.active {
        font-weight: bold;
      }

      .bluetooth.disconnected {
        opacity: 0.5;
      }

      .preview .large-icons {
        -gtk-icon-size: 64px;
      }

      .keybinds {
        padding-top: 10px;
        border-top: 1px solid #313244;
        font-size: 12px;
        color: @theme_fg_color;
      }

      .keybind-button {
        opacity: 0.5;
      }

      .keybind-button:hover {
        opacity: 0.75;
      }

      .keybind-bind {
        text-transform: lowercase;
        opacity: 0.35;
      }

      .keybind-label {
        padding: 2px 4px;
        border-radius: 4px;
        border: 1px solid @theme_fg_color;
      }

      .error {
        padding: 10px;
        background: @error_bg_color;
        color: @error_fg_color;
      }

      :not(.calc).current {
        font-style: italic;
      }

      .preview-content.archlinuxpkgs,
      .preview-content.dnfpackages {
        font-family: monospace;
      }
    '';
  };

  # SSH agent configuration
  services.ssh-agent = {
    enable = true;
  };

  # SSH configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
      };
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/bluescorpian";
        IdentitiesOnly = true;
        AddKeysToAgent = "yes";
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
    context = ../../claude/CLAUDE.md;
    skills = ../../claude/skills;
    mcpServers = {
      claude-conversation-search = {
        type = "stdio";
        command = "claude-conversation-search";
        args = [ "mcp" ];
      };
    };
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
  home.file.".claude/hooks/conversation-search-uuid-hint.sh" = {
    source = ../../claude/hooks/conversation-search-uuid-hint.sh;
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

  # Keybindings cheatsheet — always-on static server so it can be bookmarked.
  # The viewer (keys_cheatsheet/index.html) fetch()es its JSON sources, which
  # browsers block over file:// (origin null), so it needs an HTTP origin.
  # This serves the folder on a fixed localhost port at login; bookmark
  # http://localhost:8787 and forget it. JSON edits are live on a browser
  # refresh — no rebuild needed. Bound to 127.0.0.1 so it's never exposed.
  systemd.user.services.keys-cheatsheet = {
    Unit = {
      Description = "Keybindings cheatsheet static server";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8787 --bind 127.0.0.1 --directory /home/shared/dotfiles/keys_cheatsheet";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # PipeWire EQ Configuration
  xdg.configFile."pipewire/pipewire.conf.d/10-filter-chain.conf".source = ./pipewire-eq.conf;

  # pnpm supply-chain hardening (global, both users). pnpm 11 reads global
  # settings from ~/.config/pnpm/config.yaml (YAML — the old INI `rc` is dead).
  # These apply to every project that doesn't override them in its own
  # pnpm-workspace.yaml, so they're a safety floor against npm supply-chain
  # attacks (Shai-Hulud-style worms, compromised version bumps). See
  # https://pnpm.io/supply-chain-security
  #
  # HM symlinks this read-only into the store; pnpm only reads it, so that's
  # fine. Running `pnpm config set … --global` would fail against the symlink —
  # intentional: global policy lives here, not in ad-hoc imperative edits.
  xdg.configFile."pnpm/config.yaml".text = ''
    # Cooldown: refuse to install any version published less than N minutes ago.
    # Malicious releases are almost always yanked within hours, so a window this
    # wide means you skip the blast radius entirely. 10080 = 7 days. pnpm 11's
    # built-in default is only 1440 (1 day); this tightens it. Lower it if the
    # lag bites, or exempt a specific hotfix with minimumReleaseAgeExclude.
    minimumReleaseAge: 10080

    # Fail the install (don't silently skip) when a dependency ships a build /
    # postinstall script that isn't on the approved list. Forces a deliberate
    # `pnpm approve-builds` decision instead of letting unknown scripts through.
    strictDepBuilds: true

    # Block transitive deps that resolve from git repos or tarball URLs instead
    # of the registry — a common smuggling path for unvetted code.
    blockExoticSubdeps: true

    # Refuse a version whose publish trust dropped vs. a prior release (e.g. lost
    # provenance / trusted-publisher status) — a signal of a hijacked package.
    trustPolicy: no-downgrade

    # Re-check that node_modules matches the lockfile before running scripts,
    # catching out-of-band tampering / drift; reinstalls to reconcile if needed.
    verifyDepsBeforeRun: install
  '';

  # XDG user directories — lets GLib (and thus Thunar) correctly resolve
  # special dirs (Documents, Downloads, etc.) via g_get_user_special_dir().
  xdg.userDirs.enable = true;
  xdg.userDirs.setSessionVariables = true;
}
