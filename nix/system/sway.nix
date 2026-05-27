{ pkgs, ... }:

# Shared sway base — enables the system-level wrapper and pulls in the
# wayland tooling that both hosts need. SDDM (configured in common.nix)
# auto-detects the session file installed by this module and offers it
# alongside Plasma. Host-specific bits (GPU env, log redirects) stay in
# the host configuration files; user-level config lives in home/sway.nix.
{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      grim
      slurp
      wl-clipboard
      wdisplays
      brightnessctl
      playerctl
    ];
    # Required on NVIDIA hosts (both desktop and laptop have NVIDIA somewhere
    # in the graphics path). Cheap to set unconditionally on AMD-only hosts.
    extraOptions = [ "--unsupported-gpu" ];
  };
}
