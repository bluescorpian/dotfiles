#!/usr/bin/env bash
# Waybar bedtime countdown — counts down to BEDTIME, then negative (overtime).
# Emits waybar JSON; prints empty text (module hides) when more than
# THRESHOLD_HOURS remain, unless ALWAYS=1. Relies on `date` + `jq` on PATH
# (both in home.packages), same as claude/statusline.sh.

# ── config ───────────────────────────────────────────────────────────────
BEDTIME="22:00"      # target time, 24h HH:MM
THRESHOLD_HOURS=5    # show once within this many hours of bedtime
ALWAYS=0             # 1 = always display the countdown
# ─────────────────────────────────────────────────────────────────────────

now=$(date +%s)
target=$(date -d "today $BEDTIME" +%s)
diff=$(( target - now ))

# Normalize into (-12h, +12h]: negative = overtime past bedtime; flips back to
# a fresh countdown 12h after bedtime. Two-sided wrap also handles after-midnight
# bedtimes (e.g. 00:30, 01:00).
if   (( diff >   43200 )); then diff=$(( diff - 86400 ))
elif (( diff <= -43200 )); then diff=$(( diff + 86400 )); fi

# Hide during the day unless within the threshold (or always-on).
if (( ALWAYS == 0 && diff > THRESHOLD_HOURS * 3600 )); then
  echo '{"text": ""}'
  exit 0
fi

abs=$diff
if (( abs < 0 )); then abs=$(( -abs )); fi
h=$(( abs / 3600 ))
m=$(( (abs % 3600) / 60 ))

if   (( diff < 0 ));    then sign="-"; class="overtime"
elif (( diff < 1800 )); then sign="";  class="soon"
else                        sign="";  class="normal"
fi

# Nerd Font moon glyph (U+F186), written as an escape rather than pasted in
# literally so it survives editors and copy-paste that quietly drop
# private-use codepoints — which is how it went missing before.
glyph=$'\uf186'
text=$(printf '%s %s%d:%02d' "$glyph" "$sign" "$h" "$m")

jq -nc --arg text "$text" --arg class "$class" --arg tt "Bedtime $BEDTIME" \
  '{text: $text, class: $class, tooltip: $tt}'
