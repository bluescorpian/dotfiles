{ config, pkgs, lib, ... }:

{
  # Posture reminder — a low-urgency toast every 30 min of continuous desk time,
  # plus the waybar countdown wired up in waybar.nix. Built to be ignorable: it
  # defers rather than fires while you're away, in fullscreen, or inside quiet
  # hours, and treats a long idle stretch as a break already taken.
  #
  # Both scripts are standalone .sh files (the waybar/bedtime.sh pattern) so the
  # interval and quiet window can be retuned by editing the file — no rebuild.
  # check.sh owns every decision; waybar.sh only renders the state it leaves.
  xdg.configFile."posture/check.sh" = {
    source = ../../posture/check.sh;
    executable = true;
  };
  xdg.configFile."posture/waybar.sh" = {
    source = ../../posture/waybar.sh;
    executable = true;
  };

  # The check runs every minute and works out for itself whether a nudge is due.
  # That granularity is the whole point: a nudge held back because you were
  # away or fullscreen lands within a minute of you becoming available, instead
  # of waiting out another full interval.
  #
  # Gated on graphical-session.target rather than sway-session.target so Plasma
  # sessions get the toast too — notify-send just lands on Plasma's own
  # notification daemon there instead of mako.
  systemd.user.services.posture-reminder = {
    Unit = {
      Description = "Posture reminder check";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.xdg.configHome}/posture/check.sh";
      # User units start from a bare PATH, so name everything check.sh shells
      # out to: swaymsg (sway), loginctl + systemd-inhibit (systemd),
      # notify-send (libnotify).
      Environment = "PATH=${lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.jq
        pkgs.libnotify
        pkgs.sway
        pkgs.systemd
      ]}";
    };
  };

  systemd.user.timers.posture-reminder = {
    Unit = {
      Description = "Posture reminder check";
      PartOf = [ "graphical-session.target" ];
    };
    Timer = {
      OnStartupSec = "2m";
      OnUnitActiveSec = "1m";
      AccuracySec = "15s";
    };
    # Only tick inside a graphical session — an SSH-only user manager has
    # nowhere to put a notification anyway.
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Sway offers no way to *query* idle time, so run a minimal swayidle purely to
  # stamp a file that check.sh reads. It only writes state — no locking, no
  # DPMS — so this does not quietly introduce an auto-lock. Under Plasma the
  # check falls back to logind's idle hint and this unit stays dormant, the same
  # way mako is gated below sway-session.target in sway.nix.
  #
  # The 60s timeout must match IDLE_DEFER_SECS in posture/check.sh, which adds
  # it back to recover how long you've actually been idle.
  systemd.user.services.posture-idle = {
    Unit = {
      Description = "Idle stamper for the posture reminder";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swayidle}/bin/swayidle -w timeout 60 'mkdir -p %t/posture && date +%%s > %t/posture/idle-since' resume 'rm -f %t/posture/idle-since'";
      Environment = "PATH=${lib.makeBinPath [ pkgs.coreutils ]}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
