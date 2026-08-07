#!/usr/bin/env bash
# Posture reminder — a low-urgency nudge every INTERVAL_MIN of continuous desk
# time. Run once a minute by the posture-reminder.timer user unit; every "should
# I stay quiet" decision lives here rather than in the timer, so a suppressed
# nudge is *deferred* and lands the moment you're available, instead of being
# dropped until the next interval comes round.
#
# Stays quiet while you're away from the desk, while something is fullscreen or
# holding an idle inhibitor (players, games), and during quiet hours. Coming
# back from a long idle stretch counts as a break already taken and silently
# resets the countdown rather than firing at you on return.
#
# State lives in $XDG_RUNTIME_DIR/posture (tmpfs, so a reboot starts fresh):
#   due     epoch seconds of the next nudge
#   status  active | away | busy | quiet, for the waybar module to render
# The companion waybar.sh only reads that state; it decides nothing itself.

set -uo pipefail

# ── config ───────────────────────────────────────────────────────────────
INTERVAL_MIN=30       # desk time between nudges
QUIET_START="22:00"   # no nudges from here...
QUIET_END="08:00"     # ...until here
IDLE_DEFER_SECS=60    # idle this long = away, hold the nudge until you're back
BREAK_SECS=300        # idle this long = break taken, reset the countdown
# ─────────────────────────────────────────────────────────────────────────
# IDLE_DEFER_SECS must match the swayidle `timeout` in nix/home/posture.nix —
# the stamp only appears once swayidle has already seen that many idle seconds,
# so idle_secs() adds it back to recover the true figure.

STATE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/posture"
mkdir -p "$STATE" || exit 0
now=$(date +%s)

# Seconds of input idleness; 0 when active or when nothing can tell us.
idle_secs() {
  # Under sway, the posture-idle unit stamps this file once swayidle has seen
  # IDLE_DEFER_SECS without input, and deletes it the instant input resumes.
  if [[ -r "$STATE/idle-since" ]]; then
    local since
    since=$(<"$STATE/idle-since")
    if [[ "$since" =~ ^[0-9]+$ ]]; then
      echo $(( now - since + IDLE_DEFER_SECS ))
      return
    fi
  fi
  # Elsewhere (Plasma) fall back to logind's idle hint, which powerdevil keeps
  # current. With neither signal, assume active — a stray nudge beats silence.
  if [[ "$(loginctl show-session "${XDG_SESSION_ID:-auto}" -p IdleHint --value 2>/dev/null)" == "yes" ]]; then
    local usec
    usec=$(loginctl show-session "${XDG_SESSION_ID:-auto}" -p IdleSinceHint --value 2>/dev/null)
    if [[ "$usec" =~ ^[0-9]+$ ]] && (( usec > 0 )); then
      echo $(( now - usec / 1000000 ))
      return
    fi
  fi
  echo 0
}

# True while whatever is on screen shouldn't be interrupted.
busy() {
  # Sway: the focused window is fullscreen (1 = window-local, 2 = global).
  #
  # Must filter to real window nodes. Sway reports fullscreen_mode=1 on
  # *workspace* nodes too, and when you focus an empty workspace the workspace
  # itself becomes the focused node — so matching on .focused alone reads as
  # "fullscreen" forever and silently wedges the reminder off.
  if [[ -n "${SWAYSOCK:-}" ]]; then
    local fs
    fs=$(swaymsg -t get_tree 2>/dev/null |
      jq -r 'first(.. | objects
                    | select(.focused? == true)
                    | select(.type? == "con" or .type? == "floating_con")
                    | .fullscreen_mode) // 0')
    [[ "$fs" =~ ^[12]$ ]] && return 0
  fi
  # Any desktop: an app holding an idle inhibitor (mpv, Steam, a browser playing
  # video) is explicitly asking not to be disturbed. This is what covers Plasma,
  # where there's no cheap fullscreen query.
  systemd-inhibit --list --mode=block 2>/dev/null | grep -qw idle && return 0
  return 1
}

# True inside the quiet window, which may wrap past midnight.
in_quiet() {
  local n=$((10#$(date +%H%M)))
  local s=$((10#${QUIET_START/:/}))
  local e=$((10#${QUIET_END/:/}))
  if (( s <= e )); then (( n >= s && n < e )); else (( n >= s || n < e )); fi
}

stamp()  { echo $(( now + INTERVAL_MIN * 60 )) > "$STATE/due"; }
status() { echo "$1" > "$STATE/status"; }

# First run of the session, or a corrupted stamp: start the clock, say nothing.
if [[ -r "$STATE/due" ]]; then due=$(<"$STATE/due"); else due=""; fi
if [[ ! "$due" =~ ^[0-9]+$ ]]; then
  stamp; status active; exit 0
fi

idle=$(idle_secs)

# Away long enough that you've already moved — count it as the break and reset.
if (( idle >= BREAK_SECS )); then
  stamp; status away; exit 0
fi

# Quiet hours: keep the countdown rolling forward so it doesn't bank hours of
# overdue debt overnight and then fire the instant the window closes.
if in_quiet; then
  stamp; status quiet; exit 0
fi

if (( now < due )); then
  status active; exit 0
fi

# Due, but held back: briefly away, or busy on screen. Deliberately does *not*
# restamp — the nudge lands as soon as you're back and out of fullscreen.
if (( idle >= IDLE_DEFER_SECS )); then
  status away; exit 0
fi
if busy; then
  status busy; exit 0
fi

# --app-name is what mako's [app-name=posture] criteria matches on to give this
# nudge its own colours (see services.mako.settings in nix/home/sway.nix), so
# don't rename it without updating that too.
#
# The synchronous hint makes a repeat nudge replace the previous one rather than
# stack another toast on top of it.
#
# No --icon on purpose: mako only resolved icons given as absolute paths here,
# never by theme name (Adwaita ships this family only under symbolic/legacy),
# so the flag was silently doing nothing.
notify-send \
  --urgency=low \
  --expire-time=8000 \
  --app-name=posture \
  --hint=string:x-canonical-private-synchronous:posture \
  "Posture check" \
  "Sit back, shoulders down, screen at eye level."

stamp
status active
