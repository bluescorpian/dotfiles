#!/usr/bin/env bash
# Claude Code statusline — Catppuccin Mocha, hairline minimal.
#
# Line 1:  project  branch ●⇡N⇣N · ctx % · 5h X% left ⏲ Hh Mm [dry~Eta] · 7d … · age·turns · model
#   `dry~Eta` appears only when, at your recent burn rate, that window will run
#   dry before it resets; the ⏲ reset time turns yellow/red to match.
# Line 2: ⤷ first user message (chat title)
#
# Reads session JSON on stdin, prints to stdout.
set -u

# --- Crash logging --------------------------------------------------------
# Claude Code silently hides the statusline whenever this script errors or
# prints nothing, so a one-off failure leaves no trace of *why*. To make those
# debuggable after the fact: redirect stderr to a scratch buffer and, only when
# the script exits non-zero, append a timestamped record (the captured error
# output + the JSON we were handed, for replay) to a log. Successful renders
# write nothing. Override the path with $CLAUDE_STATUSLINE_LOG.
LOG="${CLAUDE_STATUSLINE_LOG:-$HOME/.claude/statusline.log}"
errbuf=$(mktemp 2>/dev/null) || errbuf=""
[[ -n "$errbuf" ]] && exec 2>"$errbuf"
_on_exit() {
  local rc=$?
  if (( rc != 0 )); then
    mkdir -p "$(dirname "$LOG")" 2>/dev/null
    # Cap the log at ~1 MB (only reached if something fails every render).
    if [[ -f "$LOG" ]] && (( $(wc -c <"$LOG" 2>/dev/null || echo 0) > 1048576 )); then
      tail -n 200 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
    fi
    {
      printf '─── %s exit=%s ───\n' "$(date '+%F %T')" "$rc"
      [[ -n "$errbuf" && -s "$errbuf" ]] && cat "$errbuf"
      printf 'stdin: %s\n' "${input-<unread>}"
    } >>"$LOG" 2>/dev/null
  fi
  [[ -n "$errbuf" ]] && rm -f "$errbuf"
}
trap _on_exit EXIT

input=$(cat)
J() { command jq -r "$1 // empty" <<<"$input"; }

# --- Catppuccin Mocha (truecolor) ---
RST=$'\e[0m'
BLUE=$'\e[38;2;137;180;250m'      # #89b4fa  project
MAUVE=$'\e[38;2;203;166;247m'     # #cba6f7  branch
GREEN=$'\e[38;2;166;227;161m'     # #a6e3a1  ok / ahead
YELLOW=$'\e[38;2;249;226;175m'    # #f9e2af  warn / dirty
RED=$'\e[38;2;243;139;168m'       # #f38ba8  danger / behind
PEACH=$'\e[38;2;250;179;135m'     # #fab387  effort=max
TEXT=$'\e[38;2;205;214;244m'      # #cdd6f4  text
SUBTEXT=$'\e[38;2;186;194;222m'   # #bac2de  subtext1 (effort=xhigh, title)
DIM=$'\e[38;2;166;173;200m'       # #a6adc8  subtext0 (effort=high, side text)
OVERLAY2=$'\e[38;2;147;153;178m'  # #9399b2  overlay2 (effort=medium)
OVERLAY1=$'\e[38;2;127;132;156m'  # #7f849c  overlay1 (effort=low)
OVERLAY=$'\e[38;2;108;112;134m'   # #6c7086  overlay0 (separators / arrow)

threshold() { # args: used_pct  is_1m_context_window
  local p=$1 is_1m=${2:-0}
  # 1M-window models: warn at 20% (200k tokens — past the standard 200k window
  # where quality starts to drift), danger at 80%.
  # 200k-window models: standard 60% / 80% bands.
  if (( is_1m )); then
    if   (( p >= 80 )); then echo "$RED"
    elif (( p >= 20 )); then echo "$YELLOW"
    else                     echo "$GREEN"
    fi
  else
    if   (( p >= 80 )); then echo "$RED"
    elif (( p >= 60 )); then echo "$YELLOW"
    else                     echo "$GREEN"
    fi
  fi
}

fmt_dur() { # seconds → compact "Dd Hh" / "Hh Mm" / "Mm"
  local s=$1 d h m
  d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 )); m=$(( (s % 3600) / 60 ))
  if   (( d > 0 )); then printf '%dd%dh' "$d" "$h"
  elif (( h > 0 )); then printf '%dh%dm' "$h" "$m"
  else                   printf '%dm'    "$m"
  fi
}

cwd=$(J '.workspace.current_dir // .cwd')
project_dir=$(J '.workspace.project_dir // .cwd')
transcript=$(J '.transcript_path')
model=$(J '.model.display_name')
effort=$(J '.effort.level')
ctx_pct_in=$(J '.context_window.used_percentage')
exceeds_200k=$(command jq -r '.exceeds_200k_tokens // false' <<<"$input")
dur_ms=$(command jq -r '.cost.total_duration_ms // 0' <<<"$input")
rl5_pct=$(J '.rate_limits.five_hour.used_percentage')
rl5_reset=$(J '.rate_limits.five_hour.resets_at')
rl7_pct=$(J '.rate_limits.seven_day.used_percentage')
rl7_reset=$(J '.rate_limits.seven_day.resets_at')

project_name=$(basename "${project_dir:-$cwd}")

# --- Git (branch + dirty + ahead/behind) ---
branch=""; dirty=""; ahead=""; behind=""
if git -C "$cwd" rev-parse --git-dir &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null \
        || echo "")
  [[ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]] && dirty="●"
  if upstream=$(git -C "$cwd" rev-parse --abbrev-ref '@{u}' 2>/dev/null); then
    counts=$(git -C "$cwd" rev-list --left-right --count "$upstream...HEAD" 2>/dev/null)
    if [[ -n "$counts" ]]; then
      b=$(awk '{print $1}' <<<"$counts")
      a=$(awk '{print $2}' <<<"$counts")
      (( a > 0 )) && ahead="⇡$a"
      (( b > 0 )) && behind="⇣$b"
    fi
  fi
fi

# --- Context % (prefer stdin; fall back to transcript scan) ---
window=200000
if [[ "$exceeds_200k" == "true" ]] || [[ "$model" == *"1M"* ]] || [[ "$model" == *"1m"* ]]; then
  window=1000000
fi
if [[ -n "$ctx_pct_in" ]]; then
  pct=${ctx_pct_in%.*}
else
  ctx_tokens=0
  if [[ -f "$transcript" ]]; then
    ctx_tokens=$(tac "$transcript" 2>/dev/null \
      | command jq -r 'select(.message.usage) | .message.usage
               | ((.input_tokens // 0)
                  + (.cache_creation_input_tokens // 0)
                  + (.cache_read_input_tokens // 0))' 2>/dev/null \
      | head -n1)
    ctx_tokens=${ctx_tokens:-0}
  fi
  pct=0
  (( window > 0 )) && pct=$(( ctx_tokens * 100 / window ))
fi

# --- Recent burn-rate tracking (shared across sessions on this machine) ---
# `used_percentage` is a *global* counter, so a single state file captures the
# true combined burn regardless of which session renders. Each render samples
# it and keeps an EWMA of Δused/Δt (%/sec) per window, so projections reflect
# *recent* pace — not the cumulative average since the window opened (which
# stays pessimistically red after a burst, or falsely green after idle).
#
# Samples closer than `mindt` are ignored (duplicate renders / no resolution);
# a gap longer than `fresh` cold-starts the baseline (idle → the old rate is no
# longer "recent"). A drop in used% means the window rolled over → rate resets.
# `valid=1` means the EWMA is trustworthy; `0` means fall back to cumulative.
rl_state="${XDG_RUNTIME_DIR:-/tmp}/claude-statusline-rl.state"
now=$(date +%s)
rl_rate5=0; rl_rate7=0; rl_rate_valid=0
_rl_prev=$(cat "$rl_state" 2>/dev/null)
_rl_new=$(awk -v now="$now" -v c5="${rl5_pct:-}" -v c7="${rl7_pct:-}" \
              -v alpha=0.3 -v mindt=3 -v fresh=900 '
  NF >= 5 { pts=$1; pu5=$2; pu7=$3; pr5=$4; pr7=$5; have=1 }
  END {
    r5=(have?pr5:0); r7=(have?pr7:0); valid=0;
    dt=(have ? now-pts : 0);
    if (have && dt > mindt && dt <= fresh) {
      valid=1;
      if (c5!="" && pu5>=0) { d=c5-pu5; r5=(d<0)?0:alpha*(d/dt)+(1-alpha)*pr5 }
      if (c7!="" && pu7>=0) { d=c7-pu7; r7=(d<0)?0:alpha*(d/dt)+(1-alpha)*pr7 }
    } else if (have && dt >= 0 && dt <= mindt) {
      valid=1;                       # duplicate render: keep the prior rate
    }                                # else: cold start / stale → fall back
    printf "%d %s %s %.8f %.8f %d", now,
      (c5==""?(have?pu5:-1):c5), (c7==""?(have?pu7:-1):c7), r5, r7, valid;
  }' <<<"$_rl_prev")
if [[ -n "$_rl_new" ]]; then
  read -r _ _ _ rl_rate5 rl_rate7 rl_rate_valid <<<"$_rl_new"
  # Persist only the first five fields (drop the valid flag). Atomic swap so
  # concurrent renders from other sessions never read a half-written file.
  { printf '%s\n' "${_rl_new% *}" >"$rl_state.tmp.$$" \
      && mv -f "$rl_state.tmp.$$" "$rl_state"; } 2>/dev/null \
    || rm -f "$rl_state.tmp.$$" 2>/dev/null
fi

# --- Rate-limit segments (5h + weekly) ---
# Two independent colors per segment:
#   - % left  → *current* state: how much quota is in the tank (fixed bands).
#   - ⏲ reset → *time margin*: compare time-to-exhaustion (remaining ÷ recent
#     burn rate) against time-to-reset. If you'll run dry first, the reset time
#     goes yellow/red and a `dry~<eta>` shows when. `green % + red time` means
#     "plenty in the tank, but at this pace you'll empty it before it resets."
#
# The `used < floor` guard (A) suppresses escalation until real consumption
# exists, so an early burst can't extrapolate to a false alarm. When no recent
# rate is available (valid=0) it falls back to the cumulative average.
# args: used_pct  reset_epoch  window_seconds  label  rate_pct_per_sec  valid
rl_segment() {
  local pct=$1 reset=$2 window=$3 label=$4 rate=${5:-0} valid=${6:-0}
  [[ -z "$pct" ]] && return 0
  local used=${pct%.*}
  local left=$(( 100 - used ))
  local lc; lc=$(threshold "$used" 0)
  local seg="${DIM}${label}${RST} ${lc}${left}%${RST} ${DIM}left${RST}"

  if [[ -n "$reset" ]]; then
    local now2 reset_epoch delta
    now2=$(date +%s)
    reset_epoch=${reset%.*}
    delta=$(( reset_epoch - now2 ))
    if (( delta > 0 )); then
      # Colour + time-to-exhaustion in float math → "<g|y|r> <dry_secs|-1>".
      local dec ccode dsec
      dec=$(awk -v used="$pct" -v rate="$rate" -v valid="$valid" \
                -v delta="$delta" -v window="$window" -v floor=15 '
        BEGIN {
          rem = 100 - used; elapsed = window - delta;
          # Prefer the recent EWMA rate; fall back to cumulative average.
          rr = (valid ? rate : (elapsed > 0 ? used / elapsed : 0));
          if (rr <= 1e-12 || used < floor) { print "g -1"; exit }
          tte = rem / rr; ratio = tte / delta;   # >1 ⇒ reset arrives first
          if      (ratio >= 1.25) print "g -1";
          else if (ratio >= 1.0)  print "y -1";          # close, but you make it
          else if (ratio >= 0.8)  printf "y %d\n", int(tte);
          else                    printf "r %d\n", int(tte);
        }')
      read -r ccode dsec <<<"$dec"
      local rc=$GREEN
      case "$ccode" in y) rc=$YELLOW ;; r) rc=$RED ;; esac
      seg+=" ${DIM}⏲${RST} ${rc}$(fmt_dur "$delta")${RST}"
      [[ -n "$dsec" && "$dsec" != "-1" ]] && seg+=" ${rc}dry~$(fmt_dur "$dsec")${RST}"
    fi
  fi
  printf '%s' "$seg"
}

rl5_seg=$(rl_segment "$rl5_pct" "$rl5_reset" 18000  "5h" "$rl_rate5" "$rl_rate_valid")
rl7_seg=$(rl_segment "$rl7_pct" "$rl7_reset" 604800 "7d" "$rl_rate7" "$rl_rate_valid")

# --- Session age + user-turn count ---
age_text=""
if (( dur_ms > 0 )); then
  secs=$(( dur_ms / 1000 ))
  if   (( secs >= 3600 )); then age_text="$(( secs / 3600 ))h$(( (secs % 3600) / 60 ))m"
  elif (( secs >= 60   )); then age_text="$(( secs / 60 ))m"
  else                          age_text="${secs}s"
  fi
fi
turns=0
# Filter user records to actual prompts: drop tool_results (array content),
# slash-command captures and system-reminders (string starting with `<`),
# and meta-injections like auto-compact continuations (isMeta=true).
if [[ -f "$transcript" ]]; then
  turns=$(command jq -c '
    select(.type == "user")
    | select((.isMeta // .message.isMeta // false) | not)
    | select(.message.content | type == "string")
    | select(.message.content | startswith("<") | not)
  ' "$transcript" 2>/dev/null | wc -l)
fi
session_text=""
[[ -n "$age_text" ]] && session_text="${age_text}·${turns}t"

# --- Chat title — prefer the session's ai-title (updated by /rename and
# Claude's auto-summary); fall back to the first real user message for
# brand-new sessions before the title has been generated.
title=""
if [[ -f "$transcript" ]]; then
  title=$(tac "$transcript" 2>/dev/null \
    | command jq -r 'select(.type == "ai-title") | .aiTitle' 2>/dev/null \
    | head -n1)
  if [[ -z "$title" ]]; then
    # Filter each record as a whole *inside* jq. Slash commands are recorded as
    # a single multi-line string (`<command-name>…\n  <command-message>…\n  …`);
    # piping that to a line-based `grep -v '^<'` would drop line 1 but leak the
    # indented `<command-message>`/`<command-args>` lines. So: drop meta records,
    # flatten array content to its text parts, collapse whitespace to one line,
    # then reject anything that starts with `<` (command/system/tool wrappers).
    title=$(command jq -r '
      select(.type == "user")
      | select((.isMeta // .message.isMeta // false) | not)
      | .message.content
      | (if type == "string" then .
         elif type == "array" then
           (map(select(.type == "text") | .text) | join(" "))
         else "" end)
      | gsub("\\s+"; " ") | sub("^ +"; "") | sub(" +$"; "")
      | select(length > 0)
      | select(startswith("<") | not)' "$transcript" 2>/dev/null \
      | head -n1)
  fi
  title=$(printf '%s' "$title" | tr -s '[:space:]' ' ' | cut -c1-80)
fi

is_1m=0
(( window == 1000000 )) && is_1m=1
ctx_color=$(threshold "$pct" "$is_1m")

sep="${OVERLAY} · ${RST}"

# --- Line 1 ---
line1="${BLUE} ${project_name}${RST}"
if [[ -n "$branch" ]]; then
  line1+=" ${MAUVE} ${branch}${RST}"
  [[ -n "$dirty"  ]] && line1+="${YELLOW}${dirty}${RST}"
  [[ -n "$ahead"  ]] && line1+="${GREEN}${ahead}${RST}"
  [[ -n "$behind" ]] && line1+="${RED}${behind}${RST}"
fi
line1+="${sep}${ctx_color}${pct}%${RST} ${DIM}ctx${RST}"
[[ -n "$rl5_seg" ]] && line1+="${sep}${rl5_seg}"
[[ -n "$rl7_seg" ]] && line1+="${sep}${rl7_seg}"
[[ -n "$session_text" ]] && line1+="${sep}${DIM}${session_text}${RST}"
[[ -n "$model"        ]] && line1+="${sep}${DIM}${model}${RST}"
if [[ -n "$effort" ]]; then
  case "$effort" in
    max)    effort_color=$PEACH    ;;
    xhigh)  effort_color=$SUBTEXT  ;;
    high)   effort_color=$DIM      ;;
    medium) effort_color=$OVERLAY2 ;;
    low)    effort_color=$OVERLAY1 ;;
    *)      effort_color=$DIM      ;;
  esac
  line1+="${sep}${effort_color}${effort}${RST}"
fi

# --- Line 2 ---
printf '%s' "$line1"
[[ -n "$title" ]] && printf '\n%s⤷%s %s%s%s' "$OVERLAY" "$RST" "$SUBTEXT" "$title" "$RST"

# Reaching here means we rendered fine. Exit 0 explicitly: the title `&&` above
# leaves a non-zero status when there's no title, which the crash log would
# otherwise mistake for a failure (and a genuine crash still exits non-zero).
exit 0
