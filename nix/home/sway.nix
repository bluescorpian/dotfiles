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
          | ${pkgs.rofi}/bin/rofi -dmenu -no-show-icons -p clipboard \
          | ${pkgs.cliphist}/bin/cliphist decode \
          | ${pkgs.wl-clipboard}/bin/wl-copy
      '';
      # Workspace picker built on rofi's dmenu mode. Existing workspace names
      # are offered, and typing a new name creates it through sway's workspace
      # command.
      # Workspace names in most-recently-visited order (newest first),
      # excluding the focused one. Recency comes from a focus-event log kept
      # by the sway-workspace-history user service (defined below) in
      # $XDG_RUNTIME_DIR (tmpfs, wiped each boot). Stale entries for
      # destroyed workspaces are dropped by intersecting with the live set,
      # and any existing workspace not yet in the log is appended in sway's
      # own order. Excluding the focused workspace floats the
      # previously-visited one to the top, so rofi preselects it and Enter
      # behaves like back_and_forth.
      wsListMru = pkgs.writeShellScript "sway-ws-list-mru" ''
        hist="''${XDG_RUNTIME_DIR}/sway-workspace-history"
        ws=$(${pkgs.sway}/bin/swaymsg -t get_workspaces)
        focused=$(printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')
        existing=$(printf '%s' "$ws" | ${pkgs.jq}/bin/jq -r '.[].name')
        {
          [ -f "$hist" ] && ${pkgs.coreutils}/bin/tac "$hist"
          printf '%s\n' "$existing"
        } | ${pkgs.gawk}/bin/awk '!seen[$0]++' | while IFS= read -r w; do
          printf '%s\n' "$existing" | ${pkgs.gnugrep}/bin/grep -qxF -- "$w" || continue
          [ "$w" = "$focused" ] && continue
          printf '%s\n' "$w"
        done
      '';
      rofiWorkspace = pkgs.writeShellScript "rofi-workspace" ''
        sel=$(${wsListMru} | ${pkgs.rofi}/bin/rofi -dmenu -no-show-icons -theme-str 'window { width: 400px; }' -p workspace)
        [ -n "$sel" ] && exec ${pkgs.sway}/bin/swaymsg workspace "$sel"
      '';
      # Same picker (same MRU ordering), but moves the focused window to the
      # chosen workspace instead of switching to it (focus stays put —
      # matches the Mod+Shift+{a,o,e,u} move convention). Typing a new name
      # and pressing Ctrl+Enter (rofi's accept-custom) creates that
      # workspace and moves the window there.
      rofiMoveToWorkspace = pkgs.writeShellScript "rofi-move-to-workspace" ''
        sel=$(${wsListMru} | ${pkgs.rofi}/bin/rofi -dmenu -no-show-icons -theme-str 'window { width: 400px; }' -p "move to workspace")
        [ -n "$sel" ] && exec ${pkgs.sway}/bin/swaymsg "move container to workspace $sel"
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
      # Auto-create the next ad-hoc workspace by num. Tier-1 occupies 1-4
      # (1:web through 4:term); pick the next integer >= 5 that's not in
      # use and switch to it. Sway names it just "5", "6", etc.
      nextAdHocWorkspace = pkgs.writeShellScript "next-adhoc-workspace" ''
        next=$(${pkgs.sway}/bin/swaymsg -t get_workspaces \
               | ${pkgs.jq}/bin/jq -r '[.[].num | select(. >= 5)] | (max // 4) + 1')
        exec ${pkgs.sway}/bin/swaymsg "workspace number $next"
      '';
      # Companion to nextAdHocWorkspace, but drags the focused window to the
      # new workspace and follows it in one atomic command. Switching to an
      # empty ad-hoc workspace (Mod+i) then trying to move a window there
      # doesn't work — sway garbage-collects the empty workspace the moment
      # it loses focus. Moving the container in first means the workspace is
      # never empty, so it survives.
      moveToNextAdHocWorkspace = pkgs.writeShellScript "move-to-next-adhoc-workspace" ''
        next=$(${pkgs.sway}/bin/swaymsg -t get_workspaces \
               | ${pkgs.jq}/bin/jq -r '[.[].num | select(. >= 5)] | (max // 4) + 1')
        exec ${pkgs.sway}/bin/swaymsg "move container to workspace number $next; workspace number $next"
      '';

      # Named-workspace bindings. Host-specific because the two machines
      # run different application mixes. The leading N: is sway's `num`
      # attribute and locks left-to-right ordering in waybar (numbered
      # workspaces always sort before unnumbered ones); ad-hoc workspaces
      # created via Mod+i pick up from num=5. Sway creates a workspace when
      # switching to a name that does not exist yet.
      laptopWorkspaces = {
        "${mod}+a" = lib.mkForce "workspace 1:web";
        "${mod}+o" = "workspace 2:notes";
        "${mod}+e" = lib.mkForce "workspace 3:code";
        "${mod}+u" = "workspace 4:term";
        "${mod}+Shift+a" = lib.mkForce "move container to workspace 1:web";
        "${mod}+Shift+o" = "move container to workspace 2:notes";
        "${mod}+Shift+e" = lib.mkForce "move container to workspace 3:code";
        "${mod}+Shift+u" = "move container to workspace 4:term";
      };
      desktopWorkspaces = {
        "${mod}+a" = lib.mkForce "workspace 1:web";
        "${mod}+o" = "workspace 2:chat";
        "${mod}+e" = lib.mkForce "workspace 3:code";
        "${mod}+u" = "workspace 4:term";
        "${mod}+Shift+a" = lib.mkForce "move container to workspace 1:web";
        "${mod}+Shift+o" = "move container to workspace 2:chat";
        "${mod}+Shift+e" = lib.mkForce "move container to workspace 3:code";
        "${mod}+Shift+u" = "move container to workspace 4:term";
      };
      namedWorkspaces =
        if isLaptop then laptopWorkspaces
        else if isDesktop then desktopWorkspaces
        else { };
    in {
      modifier = mod;
      terminal = "kitty";
      menu = "walker";

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
        # Tab = rofi workspace picker (switch); Shift = same picker but move
        # the focused window there (focus stays put), matching the Shift=move
        # convention. Replaces the old back_and_forth toggle on Mod+Tab.
        "${mod}+Tab"       = "exec ${rofiWorkspace}";
        "${mod}+Shift+Tab" = "exec ${rofiMoveToWorkspace}";

        # Spawn the next free numbered workspace (5+) without a name prompt
        # — removes the friction of inventing a name for throwaway spaces.
        "${mod}+i" = "exec ${nextAdHocWorkspace}";
        # Send the focused window to a fresh ad-hoc workspace and follow it.
        "${mod}+Shift+i" = "exec ${moveToNextAdHocWorkspace}";

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
        # Power menu (lock/logout/suspend/reboot/shutdown) — see
        # programs.wlogout below. Replaces the old exit-only swaynag prompt;
        # wlogout's click-to-confirm buttons serve the same purpose.
        "${mod}+Shift+End" = "exec ${pkgs.wlogout}/bin/wlogout --buttons-per-row 5";

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
      # External monitor (Dell S2421HN, 1920x1080 @ scale 1.0) sits on the
      # left at logical origin; the laptop panel sits flush to its right.
      # HDMI-A-1's logical width is 1920, so eDP-1 starts at pos 1920.
      # eDP-1 runs at scale 1.25, so its own logical width is 1920/1.25 = 1536.
      output = lib.mkIf isLaptop {
        "HDMI-A-1" = { mode = "1920x1080"; pos = "0 0"; };
        "eDP-1"    = { mode = "1920x1080"; pos = "1920 0"; scale = "1.25"; };
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

  # Power menu — lock/logout/suspend/reboot/shutdown, launched via
  # Mod+Shift+End (bound above). Catppuccin Mocha styling to match the
  # rest of the sway theme (rofi/mako/sway colors in common.nix / above).
  programs.wlogout = {
    enable = true;
    layout = [
      { label = "lock"; text = "Lock"; keybind = "l"; action = "${pkgs.swaylock}/bin/swaylock -c 1e1e2e"; }
      { label = "logout"; text = "Logout"; keybind = "e"; action = "${pkgs.sway}/bin/swaymsg exit"; }
      { label = "suspend"; text = "Suspend"; keybind = "s"; action = "${pkgs.systemd}/bin/systemctl suspend"; }
      { label = "reboot"; text = "Reboot"; keybind = "r"; action = "${pkgs.systemd}/bin/systemctl reboot"; }
      { label = "shutdown"; text = "Shutdown"; keybind = "p"; action = "${pkgs.systemd}/bin/systemctl poweroff"; }
    ];
    style = ''
      * {
        background-image: none;
        box-shadow: none;
      }

      window {
        background-color: rgba(30, 30, 46, 0.85);
      }

      button {
        color: #cdd6f4;
        background-color: #313244;
        border-style: solid;
        border-width: 2px;
        border-color: #45475a;
        border-radius: 12px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
        margin: 10px;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
      }

      button:focus, button:active, button:hover {
        background-color: #cba6f7;
        color: #1e1e2e;
        border-color: #cba6f7;
        outline-style: none;
      }

      #lock {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
      }

      #reboot {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      }

      #shutdown {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      }
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

  # Night light / red shift. gammastep is the wlroots-native redshift fork;
  # it drives the wlr-gamma-control protocol that sway implements. Manual
  # provider with fixed coordinates (Gqeberha / Port Elizabeth) so it tracks
  # real sunset/sunrise year-round without depending on geoclue's flaky
  # IP/WiFi geolocation. Day stays neutral (6500K), night goes deep amber
  # (3500K). Tweak the temperatures or swap to dawnTime/duskTime if you'd
  # rather pin the transition to clock times.
  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = -33.9796;
    longitude = 25.6598;
    temperature = {
      day = 6500;
      night = 3500;
    };
    # Brightness rides the same sunset/sunrise schedule. This is a *software*
    # dim — gammastep scales the gamma ramp (0.1–1.0), not the hardware
    # backlight (which external desktop monitors don't expose to brightnessctl
    # anyway). Day at full, night dimmed to 0.8. Drop the night value for a
    # stronger dim.
    settings.general = {
      brightness-day = 1.0;
      brightness-night = 0.8;
    };
  };

  # Re-gate the home-manager gammastep unit onto sway-session.target. By
  # default it binds to graphical-session.target, which Plasma also reaches —
  # but KWin doesn't implement wlr-gamma-control, so under KDE gammastep would
  # fail and (Restart=always) restart-loop. Plasma has its own Night Color
  # anyway. mkForce replaces the module's list rather than appending, so the
  # unit no longer wants graphical-session.target at all.
  systemd.user.services.gammastep = {
    Unit.PartOf = lib.mkForce [ "sway-session.target" ];
    Unit.After = lib.mkForce [ "sway-session.target" ];
    Install.WantedBy = lib.mkForce [ "sway-session.target" ];
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

  # Records sway workspace focus order so the rofi pickers can list
  # workspaces most-recently-visited first (consumed by wsListMru above).
  # Subscribes to sway's workspace events and appends each newly-focused
  # workspace name to a log in $XDG_RUNTIME_DIR (tmpfs). Gated on
  # sway-session.target like the cliphist watchers; the log is truncated on
  # each start so visit history never carries across sessions.
  systemd.user.services.sway-workspace-history = {
    Unit = {
      Description = "Track sway workspace focus order (MRU) for the rofi pickers";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "sway-workspace-history" ''
        hist="''${XDG_RUNTIME_DIR}/sway-workspace-history"
        : > "$hist"
        ${pkgs.sway}/bin/swaymsg -t subscribe -m '["workspace"]' \
          | ${pkgs.jq}/bin/jq --unbuffered -r 'select(.change=="focus") | .current.name' \
          >> "$hist"
      ''}";
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
