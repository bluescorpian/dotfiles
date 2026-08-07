#!/usr/bin/env bash
# Waybar posture module — renders the countdown that check.sh maintains in
# $XDG_RUNTIME_DIR/posture. Display only: every decision about when to nudge
# lives in check.sh, so this never fires or suppresses anything itself.
#
# Emits waybar JSON, and prints empty text (the module hides) while more than
# THRESHOLD_MIN remain or while the reminder is paused — so the bar is untouched
# almost all of the time and only surfaces as a nudge actually approaches.
# Relies on `date` + `jq` on PATH, same as waybar/bedtime.sh.

# ── config ───────────────────────────────────────────────────────────────
THRESHOLD_MIN=10   # start showing once the next nudge is this close
ALWAYS=0           # 1 = always display the countdown
# ─────────────────────────────────────────────────────────────────────────

STATE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/posture"
now=$(date +%s)

due=$(cat "$STATE/due" 2>/dev/null)
state=$(cat "$STATE/status" 2>/dev/null)

# No state yet — the timer hasn't run since login.
if [[ ! "$due" =~ ^[0-9]+$ ]]; then
  echo '{"text": ""}'
  exit 0
fi

# Paused (away, fullscreen, or quiet hours): hide rather than show a countdown
# that isn't really ticking. Nobody is reading the bar in the first two cases —
# fullscreen covers it outright — and a frozen number would just be misleading.
if [[ -n "$state" && "$state" != "active" ]]; then
  echo '{"text": ""}'
  exit 0
fi

diff=$(( due - now ))

if (( ALWAYS == 0 && diff > THRESHOLD_MIN * 60 )); then
  echo '{"text": ""}'
  exit 0
fi

abs=$diff
if (( abs < 0 )); then abs=$(( -abs )); fi
m=$(( abs / 60 ))

if   (( diff < 0 ));   then sign="-"; class="overdue"; tt="Posture nudge overdue by ${m}m"
elif (( diff < 300 )); then sign="";  class="soon";    tt="Next posture nudge in ${m}m"
else                        sign="";  class="normal";  tt="Next posture nudge in ${m}m"
fi

# Nerd Font standing-figure glyph (U+F183), written as an escape rather than
# pasted in literally so it survives editors and copy-paste that quietly drop
# private-use codepoints — which is how bedtime.sh lost its moon.
glyph=$'\uf183'
text=$(printf '%s %s%dm' "$glyph" "$sign" "$m")

jq -nc --arg text "$text" --arg class "$class" --arg tt "$tt" \
  '{text: $text, class: $class, tooltip: $tt}'
