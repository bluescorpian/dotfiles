{ pkgs, lib, ... }:

let
  # sudo -A execs its askpass helper with the prompt string as $1 and reads the
  # password from stdout — that is the entire interface, so a plain helper can
  # only ever show "[sudo] password for <user>". Everything about *what* is
  # being authorised is recoverable from /proc instead: sudo is our parent, so
  # its cmdline is the command, and its ancestors carry the caller's cwd and
  # (for agent sessions) CLAUDE_CODE_SESSION_ID.
  askpass = pkgs.writeShellApplication {
    name = "sudo-askpass";
    runtimeInputs = with pkgs; [ rofi coreutils gnused gawk gnugrep procps ];
    # No errexit/nounset: nearly every lookup below is allowed to come up empty
    # on an unusual process tree, and a failed askpass reads as a wrong password.
    bashOptions = [ "pipefail" ];
    text = ''
      esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
      ppid_of() { awk '{print $4}' "/proc/$1/stat" 2>/dev/null; }
      envof() { tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | sed -n "s/^$2=//p" | head -1; }

      # --- what is being authorised -------------------------------------
      # Drop sudo's own argv[0] and its leading flags to leave the real command.
      raw=$(tr '\0' ' ' < "/proc/$PPID/cmdline" 2>/dev/null)
      cmd=$(printf '%s' "$raw" | awk '{$1=""; sub(/^ +/,"");
                                       while ($1 ~ /^-/) { $1=""; sub(/^ +/,"") }; print}')
      [ -n "$cmd" ] || cmd="(credential refresh — no command)"

      # --- who is asking -------------------------------------------------
      # Walk up from sudo until a Claude session or a terminal identifies itself.
      caller="unknown caller"
      where=""
      pid=$(ppid_of "$PPID")
      for _ in $(seq 1 12); do
        { [ -n "''${pid:-}" ] && [ "$pid" != "0" ] && [ "$pid" != "1" ]; } || break
        [ -n "$where" ] || where=$(readlink "/proc/$pid/cwd" 2>/dev/null)

        sid=$(envof "$pid" CLAUDE_CODE_SESSION_ID)
        if [ -n "$sid" ]; then
          # The session's human-readable name is the last ai-title record in its
          # transcript; the transcript lives under a slugified project path.
          proj=$(envof "$pid" CLAUDE_PROJECT_DIR)
          slug=$(printf '%s' "''${proj:-$where}" | sed 's#/#-#g')
          title=$(grep -o '"aiTitle":"[^"]*"' \
                    "$HOME/.claude/projects/$slug/$sid.jsonl" 2>/dev/null \
                  | tail -1 | cut -d'"' -f4)
          caller="Claude Code — ''${title:-untitled session}  [''${sid:0:8}]"
          break
        fi

        comm=$(cat "/proc/$pid/comm" 2>/dev/null)
        case "$comm" in
          kitty*|konsole*|foot*|alacritty*) caller="terminal · $comm (pid $pid)"; break ;;
          sway|systemd)                     caller="$comm (pid $pid)"; break ;;
        esac
        pid=$(ppid_of "$pid")
      done

      mesg="<b>$(esc "$cmd")</b>
<span alpha='60%'>in </span>$(esc "''${where:-unknown directory}")
<span alpha='60%'>asked by </span>$(esc "$caller")"

      # sudo -A is routinely driven from shells with no display in their env
      # (agent sessions, cron); without this the dialog silently returns empty,
      # which sudo reports as a wrong password.
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"

      # A private pidfile: rofi refuses to start while another instance holds
      # the default one, so without this the prompt fails whenever the launcher
      # or a picker happens to be open.
      exec rofi \
        -pid "''${XDG_RUNTIME_DIR:-/tmp}/rofi-sudo-askpass.pid" \
        -dmenu -password -lines 0 \
        -p "''${1%% for*}" \
        -mesg "$mesg" \
        -window-title "sudo authorisation" \
        -theme-str 'window { width: 55%; } entry { placeholder: "password"; }' \
        < /dev/null
    '';
  };
in
{
  home.sessionVariables.SUDO_ASKPASS = lib.getExe askpass;
}
