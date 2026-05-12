{ config, pkgs, lib, ... }:

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
    anydesk

    # Sway ecosystem
    i3status              # status command for swaybar
    swaylock              # screen locker
    grim                  # screenshot
    slurp                 # region picker
    wl-clipboard          # wl-copy / wl-paste
    wdisplays             # GUI output configurator
    brightnessctl
    playerctl
    pavucontrol
    networkmanagerapplet
  ];

  # Sway compositor (Wayland session, offered by SDDM alongside Plasma).
  # System-level enablement is in system/laptop/configuration.nix.
  wayland.windowManager.sway = {
    enable = true;
    # Don't let home-manager install its own sway wrapper. The system-level
    # `programs.sway` (in system/laptop/configuration.nix) ships a wrapper
    # with the multi-GPU WLR_DRM_DEVICES export, the --unsupported-gpu flag,
    # and the stdout/stderr redirect to ~/sway-session.log. If both modules
    # install a wrapped sway, the per-user profile wins on $PATH and SDDM
    # ends up launching the home-manager wrapper, which knows nothing about
    # any of that — back to a blinking cursor on hybrid GPUs. With
    # package=null, home-manager still writes ~/.config/sway/config from
    # this block but leaves the binary to the system wrapper.
    package = null;
    config = let mod = "Mod4"; in {
      modifier = mod;
      terminal = "kitty";
      menu = "wofi --show drun";

      # Add bindings on top of the home-manager sway module defaults
      # (focus arrows, kill, reload, layout toggles, etc).
      keybindings = lib.mkOptionDefault {
        "${mod}+Shift+s" = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";
        "${mod}+Shift+x" = "exec swaylock -c 1e1e2e";

        # Cycle workspaces on the focused output with Mod+Ctrl+Arrows.
        # Add Shift to drag the focused container along.
        "${mod}+Ctrl+Left"        = "workspace prev_on_output";
        "${mod}+Ctrl+Right"       = "workspace next_on_output";
        "${mod}+Ctrl+Shift+Left"  = "move container to workspace prev_on_output; workspace prev_on_output";
        "${mod}+Ctrl+Shift+Right" = "move container to workspace next_on_output; workspace next_on_output";

        "XF86AudioRaiseVolume"  = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume"  = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute"         = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute"      = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86MonBrightnessUp"   = "exec brightnessctl set 5%+";
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        "XF86AudioPlay"         = "exec playerctl play-pause";
        "XF86AudioNext"         = "exec playerctl next";
        "XF86AudioPrev"         = "exec playerctl previous";

        # Suppress keysym digit bindings. Under Dvorak Programmer the digit
        # keysyms live on the shifted layer in non-monotonic order, so
        # Mod+<physical-digit-key> jumps to the wrong workspace via keysym.
        # Replaced below by keycodebindings, which fire on physical position.
        "${mod}+1" = lib.mkForce null;
        "${mod}+2" = lib.mkForce null;
        "${mod}+3" = lib.mkForce null;
        "${mod}+4" = lib.mkForce null;
        "${mod}+5" = lib.mkForce null;
        "${mod}+6" = lib.mkForce null;
        "${mod}+7" = lib.mkForce null;
        "${mod}+8" = lib.mkForce null;
        "${mod}+9" = lib.mkForce null;
        "${mod}+0" = lib.mkForce null;
        "${mod}+Shift+1" = lib.mkForce null;
        "${mod}+Shift+2" = lib.mkForce null;
        "${mod}+Shift+3" = lib.mkForce null;
        "${mod}+Shift+4" = lib.mkForce null;
        "${mod}+Shift+5" = lib.mkForce null;
        "${mod}+Shift+6" = lib.mkForce null;
        "${mod}+Shift+7" = lib.mkForce null;
        "${mod}+Shift+8" = lib.mkForce null;
        "${mod}+Shift+9" = lib.mkForce null;
        "${mod}+Shift+0" = lib.mkForce null;
      };

      # Workspace switching by physical key position (keycodes 10..19 =
      # top-row keys 1..0 on QWERTY layout, regardless of the active xkb
      # variant). Lets Mod+<physical-1-key> always go to workspace 1, etc.
      keycodebindings = {
        "${mod}+10" = "workspace number 1";
        "${mod}+11" = "workspace number 2";
        "${mod}+12" = "workspace number 3";
        "${mod}+13" = "workspace number 4";
        "${mod}+14" = "workspace number 5";
        "${mod}+15" = "workspace number 6";
        "${mod}+16" = "workspace number 7";
        "${mod}+17" = "workspace number 8";
        "${mod}+18" = "workspace number 9";
        "${mod}+19" = "workspace number 10";
        "${mod}+Shift+10" = "move container to workspace number 1";
        "${mod}+Shift+11" = "move container to workspace number 2";
        "${mod}+Shift+12" = "move container to workspace number 3";
        "${mod}+Shift+13" = "move container to workspace number 4";
        "${mod}+Shift+14" = "move container to workspace number 5";
        "${mod}+Shift+15" = "move container to workspace number 6";
        "${mod}+Shift+16" = "move container to workspace number 7";
        "${mod}+Shift+17" = "move container to workspace number 8";
        "${mod}+Shift+18" = "move container to workspace number 9";
        "${mod}+Shift+19" = "move container to workspace number 10";
      };

      bars = [{
        statusCommand = "${pkgs.i3status}/bin/i3status";
        position = "top";
        fonts = {
          names = [ "JetBrains Mono" "monospace" ];
          size = 10.0;
        };
      }];

      gaps = {
        inner = 6;
        outer = 0;
      };

      # Per-output config. Sway silently ignores blocks for outputs that
      # aren't present, so listing both names covers the docked + undocked
      # cases. Connector names follow the kernel DRM convention under the
      # AMD iGPU (sway runs on amdgpu, not the dGPU, via PRIME render-offload).
      # eDP-1 runs at scale 1.25, so its logical width is 1920/1.25 = 1536.
      # HDMI-A-1 sits flush to the right at logical position 1536, not 1920.
      output = {
        "eDP-1"    = { mode = "1920x1080"; pos = "0 0";    scale = "1.25"; };
        "HDMI-A-1" = { mode = "1920x1080"; pos = "1536 0"; };
      };

      # Pin workspaces to outputs. Sway falls back to the active output if
      # the named one is absent, so this is safe when the external monitor
      # is disconnected (workspaces 6-9 land on eDP).
      workspaceOutputAssign = [
        { workspace = "1"; output = "eDP-1"; }
        { workspace = "2"; output = "eDP-1"; }
        { workspace = "3"; output = "eDP-1"; }
        { workspace = "4"; output = "eDP-1"; }
        { workspace = "5"; output = "eDP-1"; }
        { workspace = "6"; output = "HDMI-A-1"; }
        { workspace = "7"; output = "HDMI-A-1"; }
        { workspace = "8"; output = "HDMI-A-1"; }
        { workspace = "9"; output = "HDMI-A-1"; }
      ];

      # Apply the system xkb layout (us/dvp) to all keyboards under sway.
      input."type:keyboard" = {
        xkb_layout = "us";
        xkb_variant = "dvp";
      };

      startup = [
        { command = "nm-applet --indicator"; }
        { command = "blueman-applet"; }
      ];
    };
  };

  # Notification daemon. Mako is the wayland-native option; gating it on
  # the sway session avoids clashing with Plasma's notification server.
  #
  # The package override strips mako's D-Bus activation file. It otherwise
  # sits in XDG_DATA_DIRS ahead of Plasma's notification service, so the
  # first notification under KDE bus-activates mako even though the systemd
  # unit is gated on sway-session.target. Under sway, systemd starts mako
  # before any notification fires, so activation isn't needed.
  services.mako = {
    enable = true;
    package = pkgs.mako.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/share/dbus-1/services/fr.emersion.mako.service
      '';
    });
    settings = {
      font = "JetBrains Mono 10";
      border-size = 1;
      border-color = "#89b4fa";
      border-radius = 6;
      padding = 8;
      background-color = "#1e1e2e";
      text-color = "#cdd6f4";
      default-timeout = 8000;
      anchor = "top-right";
      margin = 12;
    };
  };

  # Only start mako under sway — Plasma ships its own notification server.
  # Home-manager's services.mako doesn't ship a systemd unit (it relies on
  # D-Bus activation, which we strip above), so define the whole unit here
  # and gate it on sway-session.target. Plasma never pulls that target in,
  # so the unit stays dormant under KDE.
  systemd.user.services.mako = {
    Unit = {
      Description = "Mako notification daemon";
      Documentation = [ "man:mako(1)" ];
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.Notifications";
      ExecStart = "${config.services.mako.package}/bin/mako";
      ExecReload = "${config.services.mako.package}/bin/makoctl reload";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

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


  # OpenClaw AI gateway — webchat at http://127.0.0.1:18789
  # Token is stored in /run/agenix/openclaw (managed by agenix, not committed)
  # TEMPORARILY DISABLED
  # programs.openclaw = {
  #   enable = true;
  #   config.gateway.mode = "local";
  # };
  # xdg.configFile."systemd/user/openclaw-gateway.service.d/token.conf".text = ''
  #   [Service]
  #   EnvironmentFile=/run/agenix/openclaw
  # '';
}
