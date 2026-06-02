{ pkgs, ... }:

{
  # Thunar file manager — for the Sway session. Unlike Dolphin its "Open
  # With" reads XDG MIME associations directly, no XDG_MENU_PREFIX needed.
  # xfconf persists Thunar settings; gvfs provides trash/sftp/mtp mounts;
  # tumbler provides thumbnail generation.
  #
  # Per-user bits (sidebar bookmarks, custom right-click actions) live in
  # home/thunar.nix.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
