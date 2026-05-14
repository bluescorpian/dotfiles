#!/usr/bin/env bash
# Claude Code statusline — Catppuccin Mocha, hairline minimal.
#
# Line 1:  project  branch ●⇡N⇣N · ctx % · 5h X% left ⏲ Hh Mm · age·turns · model
# Line 2: ⤷ first user message (chat title)
#
# Reads session JSON on stdin, prints to stdout.
set -u

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

# --- 5h rate limit ---
# Two independent colors on this segment:
#   - % left is colored by *current* state (how much quota is in the tank).
#   - ⏲ time-to-reset is colored by *projected* state — extrapolating the
#     current burn rate over the rest of the window. So `green % + red time`
#     means "you look fine right now but you'll exhaust before reset."
#
# Projection: assuming the burn rate so far holds, projected_used =
# current_used × 5h / time_elapsed_in_window. If projected ≥ 100, you run out.
rl5_left_colored=""
rl5_reset_colored=""
if [[ -n "$rl5_pct" ]]; then
  rl5_used=${rl5_pct%.*}
  rl5_left=$(( 100 - rl5_used ))
  rl5_left_color=$(threshold "$rl5_used" 0)
  rl5_left_colored="${rl5_left_color}${rl5_left}%${RST} ${DIM}left${RST}"

  if [[ -n "$rl5_reset" ]]; then
    now=$(date +%s)
    reset_epoch=${rl5_reset%.*}
    delta=$(( reset_epoch - now ))
    if (( delta > 0 )); then
      h=$(( delta / 3600 ))
      m=$(( (delta % 3600) / 60 ))
      if (( h > 0 )); then reset_text="${h}h${m}m"
      else                  reset_text="${m}m"
      fi

      # Project: < 10 min of data or 0% used → not enough signal, stay green.
      reset_color=$GREEN
      elapsed=$(( 5*3600 - delta ))
      if (( elapsed >= 600 && rl5_used > 0 )); then
        projected=$(( rl5_used * 18000 / elapsed ))
        if   (( projected >= 100 )); then reset_color=$RED
        elif (( projected >= 80  )); then reset_color=$YELLOW
        fi
      fi
      rl5_reset_colored="${DIM}⏲${RST} ${reset_color}${reset_text}${RST}"
    fi
  fi
fi

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
    title=$(command jq -r '
      select(.type == "user")
      | .message.content
      | if type == "string" then .
        elif type == "array" then
          (map(select(.type == "text") | .text) | join(" "))
        else "" end' "$transcript" 2>/dev/null \
      | grep -v '^<' \
      | grep -v '^$' \
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
if [[ -n "$rl5_left_colored" ]]; then
  line1+="${sep}${DIM}5h${RST} ${rl5_left_colored}"
  [[ -n "$rl5_reset_colored" ]] && line1+=" ${rl5_reset_colored}"
fi
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
