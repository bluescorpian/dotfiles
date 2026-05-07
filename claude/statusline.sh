#!/usr/bin/env bash
# Claude Code statusline: project/branch · context % · chat title
# Reads session JSON on stdin, prints one line to stdout.
set -u

input=$(cat)

cwd=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
project_dir=$(jq -r '.workspace.project_dir // ""' <<<"$input")
transcript=$(jq -r '.transcript_path // ""' <<<"$input")
model=$(jq -r '.model.display_name // ""' <<<"$input")
exceeds_200k=$(jq -r '.exceeds_200k_tokens // false' <<<"$input")

project_name=$(basename "${project_dir:-$cwd}")

branch=""
if git -C "$cwd" rev-parse --git-dir &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null \
        || echo "")
fi

# Context window — 1M for [1m] models, otherwise 200k
window=200000
if [[ "$exceeds_200k" == "true" ]] || [[ "$model" == *"1M"* ]] || [[ "$model" == *"1m"* ]]; then
  window=1000000
fi

# Latest token usage from transcript (input + cache_creation + cache_read)
ctx_tokens=0
if [[ -f "$transcript" ]]; then
  ctx_tokens=$(tac "$transcript" 2>/dev/null \
    | jq -r 'select(.message.usage) | .message.usage
             | ((.input_tokens // 0)
                + (.cache_creation_input_tokens // 0)
                + (.cache_read_input_tokens // 0))' 2>/dev/null \
    | head -n1)
  ctx_tokens=${ctx_tokens:-0}
fi

pct=0
(( window > 0 )) && pct=$(( ctx_tokens * 100 / window ))

# Chat title — first real user message, trimmed to 50 chars
title=""
if [[ -f "$transcript" ]]; then
  title=$(jq -r '
    select(.type == "user")
    | .message.content
    | if type == "string" then .
      elif type == "array" then
        (map(select(.type == "text") | .text) | join(" "))
      else "" end' "$transcript" 2>/dev/null \
    | grep -v '^<' \
    | grep -v '^$' \
    | head -n1 \
    | tr -s '[:space:]' ' ' \
    | cut -c1-50)
fi

# Colors
DIM=$'\e[2m'; RST=$'\e[0m'
CYAN=$'\e[36m'; MAGENTA=$'\e[35m'
GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'

if   (( pct >= 80 )); then pct_color=$RED
elif (( pct >= 60 )); then pct_color=$YELLOW
else                       pct_color=$GREEN
fi

out="${CYAN}${project_name}${RST}"
[[ -n "$branch" ]] && out+="${DIM}@${RST}${MAGENTA}${branch}${RST}"
out+=" ${DIM}·${RST} ${pct_color}${pct}%${RST} ${DIM}ctx${RST}"
[[ -n "$model" ]] && out+=" ${DIM}·${RST} ${DIM}${model}${RST}"
[[ -n "$title" ]] && out+=" ${DIM}·${RST} ${title}"

printf '%s' "$out"
