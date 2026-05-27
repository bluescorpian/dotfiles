{ config, pkgs, lib, osConfig, ... }:

# Sway user-level config — keybindings, colors, mako/cliphist user units.
# Shared between both users on both hosts. Host-specific bits (named
# workspace layout, per-output configuration) branch on the NixOS
# hostname via osConfig.
#
# System-level enablement (programs.sway) lives in system/sway.nix.

let
  host = osConfig.networking.hostName;
  isLaptop = host == "laptop";
  isDesktop = host == "desktop";
in
{
  imports = [
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    # Sway ecosystem
    swaylock              # screen locker
    grim                  # screenshot
    slurp                 # region picker
    wl-clipboard          # wl-copy / wl-paste
    cliphist              # clipboard history (Mod+Shift+V picker via rofi)
    wl-clip-persist       # keep clipboard alive after source app closes
    wdisplays             # GUI output configurator
    brightnessctl
    playerctl
    pavucontrol
    networkmanagerapplet
  ];

  # Sway compositor (Wayland session, offered by SDDM alongside Plasma).
  wayland.windowManager.sway = {
    enable = true;
    # Don't let home-manager install its own sway wrapper. The system-level
    # `programs.sway` (in system/sway.nix) ships a wrapper with the
    # --unsupported-gpu flag (plus per-host GPU env on laptop). If both
    # modules install a wrapped sway, the per-user profile wins on $PATH
    # and SDDM ends up launching the home-manager wrapper, which knows
    # nothing about that — back to a blinking cursor on NVIDIA. With
    # package=null, home-manager still writes ~/.config/sway/config from
    # this block but leaves the binary to the system wrapper.
    package = null;
    config = let
      mod = "Mod4";
      # Clipboard history picker. cliphist's two watcher services (one for
      # text, one for images, defined below as systemd user units) feed a
      # local db; this script lists entries through rofi, decodes the pick,
      # and pumps it back into the wayland clipboard via wl-copy. Image
      # entries show as `<binary data ...>` placeholders in the list but
      # decode and paste correctly.
      cliphistPick = pkgs.writeShellScript "cliphist-pick" ''
        ${pkgs.cliphist}/bin/cliphist list \
          | ${pkgs.rofi}/bin/rofi -dmenu -p clipboard \
          | ${pkgs.cliphist}/bin/cliphist decode \
          | ${pkgs.wl-clipboard}/bin/wl-copy
      '';
      # Workspace picker built on rofi's dmenu mode. Existing workspace names
      # are offered, and typing a new name creates it through sway's workspace
      # command.
      rofiWorkspace = pkgs.writeShellScript "rofi-workspace" ''
        sel=$(${pkgs.sway}/bin/swaymsg -t get_workspaces \
              | ${pkgs.jq}/bin/jq -r '.[].name' \
              | ${pkgs.rofi}/bin/rofi -dmenu -p workspace)
        [ -n "$sel" ] && exec ${pkgs.sway}/bin/swaymsg workspace "$sel"
      '';
      # `move workspace to output` only accepts {left,right,up,down,<name>} —
      # `next` works for `focus output` but not here. This script toggles the
      # focused workspace to whichever other active output exists.
      moveWorkspaceOtherOutput = pkgs.writeShellScript "move-workspace-other-output" ''
        cur=$(${pkgs.sway}/bin/swaymsg -t get_outputs \
              | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')
        tgt=$(${pkgs.sway}/bin/swaymsg -t get_outputs \
              | ${pkgs.jq}/bin/jq -r --arg c "$cur" '.[] | select(.name != $c and .active) | .name' \
              | head -1)
        [ -n "$tgt" ] && exec ${pkgs.sway}/bin/swaymsg "move workspace to output $tgt"
      '';

      # Named-workspace bindings. Host-specific because the two machines
      # run different application mixes. Sway creates a workspace when
      # switching to a name that does not exist yet.
      laptopWorkspaces = {
        "${mod}+a" = lib.mkForce "workspace web";
        "${mod}+o" = "workspace notes";
        "${mod}+e" = lib.mkForce "workspace code";
        "${mod}+u" = "workspace term";
        "${mod}+Shift+a" = lib.mkForce "move container to workspace web";
        "${mod}+Shift+o" = "move container to workspace notes";
        "${mod}+Shift+e" = lib.mkForce "move container to workspace code";
        "${mod}+Shift+u" = "move container to workspace term";
      };
      desktopWorkspaces = {
        "${mod}+a" = lib.mkForce "workspace web";
        "${mod}+o" = "workspace chat";
        "${mod}+e" = lib.mkForce "workspace code";
        "${mod}+u" = "workspace term";
        "${mod}+Shift+a" = lib.mkForce "move container to workspace web";
        "${mod}+Shift+o" = "move container to workspace chat";
        "${mod}+Shift+e" = lib.mkForce "move container to workspace code";
        "${mod}+Shift+u" = "move container to workspace term";
      };
      namedWorkspaces =
        if isLaptop then laptopWorkspaces
        else if isDesktop then desktopWorkspaces
        else { };
    in {
      modifier = mod;
      terminal = "kitty";
      menu = "rofi -show drun";

      # Add bindings on top of the home-manager sway module defaults
      # (focus arrows, kill, reload, layout toggles, etc).
      keybindings = lib.mkOptionDefault ({
        # Region screenshot → clipboard. Bound to the keyboard's Print key
        # (the framed-camera icon on the F-row); Mod+Shift+s is freed for
        # the htns move-right symmetry below.
        "Print" = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";

        # Dvorak-friendly focus/move: htns sits on the right-hand home row
        # under dvp (physical J/K/L/;), unlike hjkl whose keysyms scatter
        # across J/C/V/P. h stays as focus-left (HM default). Mod+s
        # overrides HM's default "layout stacking" (re-bound to Mod+Shift+w
        # below, pairing with Mod+w = tabbed) and Mod+l takes the screen
        # lock.
        "${mod}+j" = lib.mkForce null;
        "${mod}+k" = lib.mkForce null;
        "${mod}+l" = lib.mkForce "exec swaylock -c 1e1e2e";
        "${mod}+t" = "focus down";
        "${mod}+n" = "focus up";
        "${mod}+s" = lib.mkForce "focus right";
        "${mod}+Shift+j" = lib.mkForce null;
        "${mod}+Shift+k" = lib.mkForce null;
        "${mod}+Shift+l" = lib.mkForce null;
        "${mod}+Shift+t" = "move down";
        "${mod}+Shift+n" = "move up";
        "${mod}+Shift+s" = "move right";
        "${mod}+Shift+w" = "layout stacking";

        # rofi — window switcher (live list of open windows) and workspace
        # picker. Both share the system Catppuccin theme from common.nix.
        "${mod}+grave"     = "exec ${pkgs.rofi}/bin/rofi -show window";
        "${mod}+Tab"       = "workspace back_and_forth";
        "${mod}+Shift+Tab" = "exec ${rofiWorkspace}";

        # Clipboard history picker (cliphist + rofi). Watchers + persist
        # daemon are systemd user units gated on sway-session.target below.
        # Mod+v stays as sway's default splitv; Shift mirrors the
        # paste-with-history convention (Win+Shift+V on Windows).
        "${mod}+Shift+v" = "exec ${cliphistPick}";

        # Cycle workspaces on the focused output with Mod+Ctrl+Arrows.
        # Add Shift to drag the focused container along.
        "${mod}+Ctrl+Left"        = "workspace prev_on_output";
        "${mod}+Ctrl+Right"       = "workspace next_on_output";
        "${mod}+Ctrl+Shift+Left"  = "move container to workspace prev_on_output; workspace prev_on_output";
        "${mod}+Ctrl+Shift+Right" = "move container to workspace next_on_output; workspace next_on_output";

        # Rebind home-manager defaults that conflict with the named
        # workspace layer and output focus.
        "${mod}+p" = "focus parent";
        "${mod}+x" = "layout toggle split";
        "${mod}+slash" = "focus mode_toggle";
        "${mod}+space" = lib.mkForce "exec ${moveWorkspaceOtherOutput}";
        "${mod}+Shift+End" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'";

        "XF86AudioRaiseVolume"  = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume"  = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute"         = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute"      = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86MonBrightnessUp"   = "exec brightnessctl set 5%+";
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        "XF86AudioPlay"         = "exec playerctl play-pause";
        "XF86AudioNext"         = "exec playerctl next";
        "XF86AudioPrev"         = "exec playerctl previous";
      } // namedWorkspaces);

      # Disable sway's built-in bar; waybar is launched from startup below.
      bars = [];

      gaps = {
        inner = 6;
        outer = 0;
      };

      # Title-bar font. Matches the rofi/waybar JetBrainsMono Nerd Font
      # already pulled in via common.nix, so no extra package needed.
      fonts = {
        names = [ "JetBrainsMono Nerd Font" ];
        size = 10.0;
      };

      # Window decorations: thin 2px border + slim title bar. `smart` edge
      # borders means the border disappears when a workspace has a single
      # tiled window, so you only see chrome when there's something to
      # disambiguate.
      window = {
        border = 2;
        titlebar = true;
        hideEdgeBorders = "smart";
      };
      floating = {
        border = 2;
        titlebar = true;
      };

      # Catppuccin Mocha palette, same hexes as the rofi theme in
      # common.nix. Sway's per-state block is: border / background / text /
      # indicator / childBorder. `childBorder` is the strip you actually
      # see around the focused container; `border` is the title-bar's own
      # outline.
      colors = {
        focused = {
          border      = "#89b4fa";
          background  = "#89b4fa";
          text        = "#1e1e2e";
          indicator   = "#a6e3a1";
          childBorder = "#89b4fa";
        };
        focusedInactive = {
          border      = "#45475a";
          background  = "#313244";
          text        = "#cdd6f4";
          indicator   = "#45475a";
          childBorder = "#313244";
        };
        unfocused = {
          border      = "#313244";
          background  = "#1e1e2e";
          text        = "#a6adc8";
          indicator   = "#313244";
          childBorder = "#313244";
        };
        urgent = {
          border      = "#f38ba8";
          background  = "#f38ba8";
          text        = "#1e1e2e";
          indicator   = "#f38ba8";
          childBorder = "#f38ba8";
        };
        placeholder = {
          border      = "#1e1e2e";
          background  = "#1e1e2e";
          text        = "#cdd6f4";
          indicator   = "#1e1e2e";
          childBorder = "#1e1e2e";
        };
        background = "#1e1e2e";
      };

      # Per-output config. Sway silently ignores blocks for outputs that
      # aren't present, so listing laptop's connectors here is harmless on
      # desktop. Connector names follow the kernel DRM convention under the
      # AMD iGPU (sway runs on amdgpu, not the dGPU, via PRIME render-offload).
      # eDP-1 runs at scale 1.25, so its logical width is 1920/1.25 = 1536.
      # HDMI-A-1 sits flush to the right at logical position 1536, not 1920.
      output = lib.mkIf isLaptop {
        "eDP-1"    = { mode = "1920x1080"; pos = "0 0";    scale = "1.25"; };
        "HDMI-A-1" = { mode = "1920x1080"; pos = "1536 0"; };
      };

      # Apply the system xkb layout (us/dvp) to all keyboards under sway.
      input."type:keyboard" = {
        xkb_layout = "us";
        xkb_variant = "dvp";
      };

      # Disable pointer acceleration for all mice. libinput defaults to the
      # "adaptive" profile (speed-dependent accel), which feels lurchy on a
      # gaming mouse. This matches the Plasma config (kcminputrc:
      # PointerAccelerationProfile=1 / PointerAcceleration=0.000) — flat
      # profile, neutral speed, i.e. raw 1:1 motion.
      input."type:pointer" = {
        accel_profile = "flat";
        pointer_accel = "0";
      };

      startup = [
        { command = "${pkgs.waybar}/bin/waybar"; }
        { command = "nm-applet --indicator"; }
        { command = "blueman-applet"; }
      ];
    };

    # Title-bar geometry knobs the home-manager module doesn't expose as
    # typed options. Padding is (horizontal, vertical) px; thickness 0
    # turns off the inner title-bar outline so the colour block reads as
    # a clean strip.
    extraConfig = ''
      titlebar_padding 8 3
      titlebar_border_thickness 0
      title_align center
    '';
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
      font = "JetBrainsMono Nerd Font 10";
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

  # Clipboard history (cliphist) + persistence (wl-clip-persist). Three
  # user units, all gated on sway-session.target so they only run under
  # sway — Plasma has Klipper for the same job. The two cliphist watchers
  # are split by MIME type because `wl-paste --watch` takes a single
  # --type filter; running both covers text and images.
  systemd.user.services.cliphist-text = {
    Unit = {
      Description = "cliphist watcher (text)";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  systemd.user.services.cliphist-image = {
    Unit = {
      Description = "cliphist watcher (images)";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  # wl-clip-persist: when the app that owns the clipboard exits, wayland
  # normally clears the selection. This daemon grabs the data first so it
  # survives. `--clipboard regular` covers Ctrl+C/V (not the X-style
  # middle-click primary selection).
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Keep wayland clipboard alive after source app closes";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
