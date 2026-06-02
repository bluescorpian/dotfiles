{ pkgs, ... }:

{
  # Thunar custom actions (right-click menu). Managing uca.xml declaratively
  # makes it a read-only store symlink, so new actions must be added here and
  # rebuilt — Thunar's "Configure custom actions" GUI can't write to it. Keep
  # the default "Open Terminal Here" example below when adding more.
  #
  # %F is passed as positional args (not inlined) so Thunar's own shell-quoting
  # survives filenames with spaces; head -c -1 strips the trailing newline so a
  # single copied path doesn't auto-execute when pasted into a shell.
  #
  # GOTCHA: Thunar pre-expands its own %-tokens (%f %F %n %N %d %D %u %U) and
  # DROPS any other "%x" before running the command — so a literal printf
  # "%s\n" becomes printf "\n" and silently copies nothing. Keep the command
  # free of stray % (hence the echo loop instead of printf "%s").
  #
  # The system-level Thunar program/services live in system/thunar.nix; sidebar
  # bookmarks (work user only) live in home-smartstation.nix.
  home.file.".config/Thunar/uca.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <actions>
    <action>
    	<icon>utilities-terminal</icon>
    	<name>Open Terminal Here</name>
    	<submenu></submenu>
    	<unique-id>1779966406147773-1</unique-id>
    	<command>exo-open --working-directory %f --launch TerminalEmulator</command>
    	<description>Example for a custom action</description>
    	<range></range>
    	<patterns>*</patterns>
    	<startup-notify/>
    	<directories/>
    </action>
    <action>
    	<icon>edit-copy</icon>
    	<name>Copy Location</name>
    	<submenu></submenu>
    	<unique-id>copy-location-1</unique-id>
    	<command>${pkgs.bash}/bin/bash -c 'for f in "$@"; do echo "$f"; done | head -c -1 | ${pkgs.wl-clipboard}/bin/wl-copy' _ %F</command>
    	<description>Copy the full path of the selected item(s) to the clipboard</description>
    	<range></range>
    	<patterns>*</patterns>
    	<directories/>
    	<audio-files/>
    	<image-files/>
    	<other-files/>
    	<text-files/>
    	<video-files/>
    </action>
    </actions>
  '';
}
