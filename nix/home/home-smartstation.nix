{ config, pkgs, lib, ... }:

let
  # Display layout script — used only by i3 (startup hook + Mod+Shift+m keybind).
  # Plasma uses its own KScreen, which is untouched.
  displays = pkgs.writeShellScriptBin "displays" ''
    set -eu
    PATH=${pkgs.xrandr}/bin:${pkgs.gnugrep}/bin:$PATH
    if xrandr | grep -q "^HDMI-1-0 connected"; then
      xrandr \
        --output eDP       --primary --mode 1920x1080 --pos 0x0    --rotate normal \
        --output HDMI-1-0            --mode 1920x1080 --pos 1920x0 --rotate normal
    else
      xrandr \
        --output eDP       --primary --mode 1920x1080 --pos 0x0 --rotate normal \
        --output HDMI-1-0  --off
    fi
  '';
in
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

    # i3 ecosystem
    rofi
    feh
    flameshot
    i3status
    i3lock
    brightnessctl
    playerctl
    pavucontrol
    networkmanagerapplet
    arandr
    xclip
    xdotool

    displays  # i3-only multi-monitor helper (defined in let-binding above)
  ];

  # i3 window manager configuration (X11 session, alongside Plasma).
  # System-level enablement is in system/laptop/configuration.nix.
  xsession.enable = true;
  xsession.windowManager.i3 = {
    enable = true;
    config = let mod = "Mod4"; in {
      modifier = mod;
      terminal = "kitty";
      menu = "rofi -show drun";

      # Add bindings on top of the home-manager i3 module defaults
      # (focus arrows, kill, reload, layout toggles, etc).
      keybindings = lib.mkOptionDefault {
        "${mod}+Tab"        = "exec rofi -show window";
        "${mod}+Shift+s"    = "exec flameshot gui";
        "${mod}+Shift+x"    = "exec i3lock -c 1e1e2e";
        "${mod}+Shift+m"    = "exec displays";  # re-detect monitors after hot-plug

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

      # Pin workspaces to outputs. i3 falls back to the active output if the
      # named one is absent, so this is safe when the external monitor is
      # disconnected (workspaces 6-9 land on eDP).
      workspaceOutputAssign = [
        { workspace = "1"; output = "eDP"; }
        { workspace = "2"; output = "eDP"; }
        { workspace = "3"; output = "eDP"; }
        { workspace = "4"; output = "eDP"; }
        { workspace = "5"; output = "eDP"; }
        { workspace = "6"; output = "HDMI-1-0"; }
        { workspace = "7"; output = "HDMI-1-0"; }
        { workspace = "8"; output = "HDMI-1-0"; }
        { workspace = "9"; output = "HDMI-1-0"; }
      ];

      startup = [
        # Set up monitors before anything else paints.
        { command = "displays"; notification = false; always = true; }
        { command = "nm-applet";       notification = false; }
        { command = "blueman-applet";  notification = false; }
      ];
    };
  };

  # Compositor — needed under i3 for vsync, fade, transparency.
  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;
    fade = true;
    fadeDelta = 4;
  };

  # Notification daemon for i3 (replaces mako, which is wayland-only).
  services.dunst = {
    enable = true;
    settings = {
      global = {
        font = "JetBrains Mono 10";
        frame_width = 1;
        frame_color = "#89b4fa";
        separator_color = "frame";
        corner_radius = 6;
        padding = 8;
        horizontal_padding = 12;
        offset = "12x12";
        origin = "top-right";
      };
      urgency_low = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        timeout = 5;
      };
      urgency_normal = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        timeout = 8;
      };
      urgency_critical = {
        background = "#1e1e2e";
        foreground = "#f38ba8";
        frame_color = "#f38ba8";
        timeout = 0;
      };
    };
  };

  # Only start dunst under i3 — Plasma ships its own notification server.
  systemd.user.services.dunst.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";

  # Application launcher (Mod+d).
  programs.rofi = {
    enable = true;
    terminal = "${pkgs.kitty}/bin/kitty";
  };

  # Force Brave to use KWallet for passwords regardless of session.
  # Plasma auto-detects KDE → kwallet5; i3 sets XDG_CURRENT_DESKTOP=i3 → falls
  # back to the "basic" store, so saved logins look missing. Pinning the flag
  # here makes both sessions share the same kdewallet entries ("Brave Safe
  # Storage"). Note: the nixpkgs brave wrapper does NOT read brave-flags.conf,
  # so the flag must live in the launcher itself.
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

  # Override Mako colors for visual distinction from personal account
  # services.mako.settings = {
  #   background-color = "#2e2e3e";
  #   border-color = "#4e4e70";
  # };
}
