#!/usr/bin/env bash
# branch-plan.sh — repo-agnostic cleanup plan for LOCAL branches that have no
# worktree (worktree branches are the other phase's job).
#
# Emits ONE JSON object on stdout:
#   { repo, trunk, defaults, branches: [ {facts..., verdict, kind, reason}, ... ] }
#
# Read-only. Verdicts are deterministic here; the agent only reasons about ASK.
# NB: squash-merged branches read as `merged:false` by ancestry but their content
# is on trunk — they land in `stale-*` ASK, and enrichment should confirm via a
# merged PR before offering a force-delete.
#
# Usage: branch-plan.sh [--trunk <branch>] [--registry <path>]
set -euo pipefail

TRUNK_ARG=""; REGISTRY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --trunk)    TRUNK_ARG="$2"; shift 2 ;;
    --registry) REGISTRY="$2";  shift 2 ;;
    *) shift ;;
  esac
done

DEF_MERGED_AGE=14; DEF_STALE=21; DEF_RECENCY=2
if [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]; then
  DEF_MERGED_AGE=$(jq -r '.defaults.mergedAgeDays      // 14' "$REGISTRY")
  DEF_STALE=$(jq -r '.defaults.staleUnmergedDays       // 21' "$REGISTRY")
  DEF_RECENCY=$(jq -r '.defaults.recencyGuardDays      // 2'  "$REGISTRY")
fi

detect_trunk() {
  if [ -n "$TRUNK_ARG" ]; then echo "$TRUNK_ARG"; return; fi
  if [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]; then
    local t; t=$(jq -r '.trunk // empty' "$REGISTRY"); [ -n "$t" ] && { echo "$t"; return; }
  fi
  for c in develop main master; do
    git show-ref --verify --quiet "refs/remotes/origin/$c" && { echo "$c"; return; }
    git show-ref --verify --quiet "refs/heads/$c"          && { echo "$c"; return; }
  done
  git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || echo main
}
TRUNK="$(detect_trunk)"
if git show-ref --verify --quiet "refs/remotes/origin/$TRUNK"; then TRUNKREF="origin/$TRUNK"; else TRUNKREF="$TRUNK"; fi

NOW=$(date +%s); TODAY=$NOW
MAIN=$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -1)
REPO_SLUG=$(basename "$MAIN")

# branches occupied by a worktree — excluded (that's the worktree phase)
WT_BRANCHES=$(git worktree list --porcelain | sed -n 's#^branch refs/heads/##p')
is_worktree_branch() { printf '%s\n' "$WT_BRANCHES" | grep -qxF "$1"; }

git for-each-ref --format='%(refname:short)' refs/heads | while read -r BR; do
  # skip trunk, the conventional trunks, and any branch that owns a worktree
  case "$BR" in "$TRUNK"|main|master) continue ;; esac
  is_worktree_branch "$BR" && continue

  HEAD=$(git rev-parse "$BR" 2>/dev/null || echo ""); [ -z "$HEAD" ] && continue

  TRACK=$(git for-each-ref --format='%(upstream:track,nobracket)' "refs/heads/$BR")
  GONE=false; [ "$TRACK" = "gone" ] && GONE=true

  BEHIND=0; AHEAD=0
  if OUT=$(git rev-list --left-right --count "$TRUNKREF...$BR" 2>/dev/null); then
    BEHIND=$(echo "$OUT" | awk '{print $1}'); AHEAD=$(echo "$OUT" | awk '{print $2}')
  fi
  if git merge-base --is-ancestor "$BR" "$TRUNKREF" 2>/dev/null; then MERGED=true; else MERGED=false; fi
  if [ -n "$(git for-each-ref --contains "$HEAD" --format='x' refs/remotes/origin 2>/dev/null | head -1)" ]; then PUSHED=true; else PUSHED=false; fi

  LASTEPOCH=$(git log -1 --format=%ct "$BR" 2>/dev/null || echo "$NOW")
  AGEDAYS=$(( (NOW - LASTEPOCH) / 86400 ))
  LASTREL=$(git log -1 --format=%cr "$BR" 2>/dev/null || echo unknown)

  KEEP="none"; NOTE=""; SNOOZE_ACTIVE=false; UNTIL=""
  if [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]; then
    KEEP=$(jq -r --arg n "$BR" '.branches[$n].keep // "none" | if type=="object" then "snooze" else . end' "$REGISTRY")
    NOTE=$(jq -r --arg n "$BR" '.branches[$n].note // ""' "$REGISTRY")
    if [ "$KEEP" = "snooze" ]; then
      UNTIL=$(jq -r --arg n "$BR" '.branches[$n].keep.until // ""' "$REGISTRY")
      [ -n "$UNTIL" ] && { UEP=$(date -d "$UNTIL" +%s 2>/dev/null || echo 0); [ "$UEP" -gt "$TODAY" ] && SNOOZE_ACTIVE=true; }
    fi
  fi

  VERDICT="KEEP"; KIND=""; REASON=""
  if [ "$KEEP" = "always" ]; then
    VERDICT="KEEP"; KIND="pinned"; REASON="registry: keep=always"
  elif $SNOOZE_ACTIVE; then
    VERDICT="KEEP"; KIND="snoozed"; REASON="registry: snoozed until $UNTIL"
  elif $GONE && $MERGED; then
    VERDICT="AUTO_DELETE"; KIND="gone-merged"; REASON="upstream deleted on origin + merged into $TRUNK"
  elif [ "$AGEDAYS" -lt "$DEF_RECENCY" ]; then
    VERDICT="KEEP"; KIND="active"; REASON="active within ${DEF_RECENCY}d (last commit $LASTREL)"
  elif $MERGED && [ "$AGEDAYS" -ge "$DEF_MERGED_AGE" ]; then
    VERDICT="AUTO_DELETE"; KIND="merged-old"; REASON="merged into $TRUNK, ${AGEDAYS}d old"
  elif $GONE; then
    VERDICT="ASK"; KIND="gone-unmerged"; REASON="upstream deleted on origin but ${AHEAD} commit(s) not in $TRUNK (squash-merged? or abandoned)"
  elif ! $MERGED && [ "$AGEDAYS" -ge "$DEF_STALE" ]; then
    if $PUSHED; then
      VERDICT="ASK"; KIND="stale-pushed"; REASON="unmerged by ancestry, idle ${AGEDAYS}d, tip on origin (likely squash-merged — confirm before delete)"
    else
      VERDICT="ASK"; KIND="stale-local"; REASON="unmerged, idle ${AGEDAYS}d, LOCAL-ONLY — deleting loses ${AHEAD} commit(s)"
    fi
  elif $MERGED; then
    VERDICT="KEEP"; KIND="merged-young"; REASON="merged but only ${AGEDAYS}d old (< ${DEF_MERGED_AGE}d)"
  else
    VERDICT="KEEP"; KIND="in-progress"; REASON="unmerged, in-progress (${AGEDAYS}d, < ${DEF_STALE}d)"
  fi

  jq -nc \
    --arg name "$BR" --arg tip "$HEAD" \
    --argjson gone "$GONE" --argjson merged "$MERGED" --argjson pushed "$PUSHED" \
    --argjson behind "$BEHIND" --argjson ahead "$AHEAD" \
    --argjson ageDays "$AGEDAYS" --arg lastRel "$LASTREL" \
    --arg keep "$KEEP" --arg note "$NOTE" \
    --arg verdict "$VERDICT" --arg kind "$KIND" --arg reason "$REASON" \
    '{name:$name,tip:$tip,gone:$gone,merged:$merged,pushed:$pushed,
      behind:$behind,ahead:$ahead,ageDays:$ageDays,lastRel:$lastRel,
      keep:$keep,note:$note,verdict:$verdict,kind:$kind,reason:$reason}'
done | jq -s \
  --arg repo "$REPO_SLUG" --arg trunk "$TRUNK" \
  --argjson mergedAge "$DEF_MERGED_AGE" --argjson stale "$DEF_STALE" --argjson recency "$DEF_RECENCY" \
  '{repo:$repo, trunk:$trunk,
    defaults:{mergedAgeDays:$mergedAge, staleUnmergedDays:$stale, recencyGuardDays:$recency},
    branches:.}'
