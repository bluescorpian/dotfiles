{ config, pkgs, ... }:

{
  # Bedtime countdown script for the custom/bedtime module below. Kept as a
  # standalone .sh (like claude/statusline.sh) and dropped next to waybar's own
  # generated config; edit BEDTIME/THRESHOLD_HOURS/ALWAYS at the top of the file.
  xdg.configFile."waybar/bedtime.sh" = {
    source = ../../waybar/bedtime.sh;
    executable = true;
  };

  # Waybar — wayland-native status bar replacing the i3status/swaybar combo.
  # Launched from sway's startup (not via systemd) so it only runs under sway,
  # not Plasma. Catppuccin Mocha palette to match kitty + mako.
  programs.waybar = {
    enable = true;
    systemd.enable = false;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 28;
      spacing = 4;

      modules-left   = [ "sway/workspaces" "sway/mode" ];
      modules-center = [ "sway/window" ];
      modules-right  = [ "tray" "pulseaudio" "network" "battery" "custom/bedtime" "clock" ];

      "sway/workspaces" = {
        disable-scroll = false;
        all-outputs = false;
      };

      "sway/window" = {
        max-length = 80;
        tooltip = false;
      };

      "sway/mode" = {
        format = "<span style=\"italic\">{}</span>";
      };

      tray = {
        icon-size = 16;
        spacing = 8;
      };

      clock = {
        format = "{:%a %d %b  %I:%M %p}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      "custom/bedtime" = {
        exec = "${config.xdg.configHome}/waybar/bedtime.sh";
        return-type = "json";
        interval = 30;
        tooltip = true;
      };

      battery = {
        states = { warning = 30; critical = 15; };
        format          = "{icon}  {capacity}%";
        format-charging = "  {capacity}%";
        format-plugged  = "  {capacity}%";
        format-icons    = [ "" "" "" "" "" ];
      };

      network = {
        format-wifi         = "  {signalStrength}%";
        format-ethernet     = "  {ifname}";
        format-disconnected = "  offline";
        tooltip-format      = "{ifname}: {ipaddr}";
      };

      pulseaudio = {
        format       = "{icon}  {volume}%";
        format-muted = "  muted";
        format-icons = {
          default   = [ "" "" "" ];
          headphone = "";
        };
        on-click = "pavucontrol";
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 12px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: #1e1e2e;
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 8px;
        color: #a6adc8;
        background: #1e1e2e;
        border-bottom: 2px solid transparent;
      }
      #workspaces button.focused {
        color: #cdd6f4;
        background: #313244;
        border-bottom: 2px solid #89b4fa;
      }
      #workspaces button.urgent {
        color: #1e1e2e;
        background: #f38ba8;
      }
      #workspaces button:hover {
        background: #313244;
        color: #cdd6f4;
        box-shadow: none;
        text-shadow: none;
      }

      #mode {
        padding: 0 10px;
        background: #f9e2af;
        color: #1e1e2e;
        font-weight: bold;
      }

      #window {
        padding: 0 10px;
        color: #bac2de;
      }

      #clock,
      #battery,
      #network,
      #pulseaudio,
      #custom-bedtime,
      #tray {
        padding: 0 10px;
        color: #cdd6f4;
        background: #1e1e2e;
      }

      #battery.warning      { color: #f9e2af; }
      #battery.critical     { color: #f38ba8; }
      #network.disconnected { color: #f38ba8; }
      #pulseaudio.muted     { color: #6c7086; }

      #custom-bedtime.soon     { color: #fab387; }                     /* orange, <30 min */
      #custom-bedtime.overtime { color: #f38ba8; font-weight: bold; }  /* red, past bedtime */

      #tray > .passive         { -gtk-icon-effect: dim; }
      #tray > .needs-attention { -gtk-icon-effect: highlight; }
    '';
  };
}
