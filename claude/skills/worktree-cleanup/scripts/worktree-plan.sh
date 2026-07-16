#!/usr/bin/env bash
# worktree-plan.sh — repo-agnostic worktree inventory + classification.
#
# Emits ONE JSON object on stdout:
#   { repo, trunk, defaults, worktrees: [ {facts..., verdict, kind, reason}, ... ] }
#
# Pure git/read-only. No mutations. Safe to run anywhere inside a repo with
# linked worktrees. Classification is deterministic here so the agent only has
# to reason about the ASK tier, not re-derive verdicts.
#
# Usage: worktree-plan.sh [--trunk <branch>] [--registry <path>] [--no-size]
set -euo pipefail

TRUNK_ARG=""
REGISTRY=""
WANT_SIZE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --trunk)    TRUNK_ARG="$2"; shift 2 ;;
    --registry) REGISTRY="$2";  shift 2 ;;
    --no-size)  WANT_SIZE=0;    shift ;;
    *) shift ;;
  esac
done

# --- defaults (overridable by registry.defaults) ---
DEF_MERGED_AGE=14
DEF_STALE_UNMERGED=21
DEF_RECENCY=2
DEF_DELETE_BRANCHES=true
if [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]; then
  DEF_MERGED_AGE=$(jq -r '.defaults.mergedAgeDays      // 14'   "$REGISTRY")
  DEF_STALE_UNMERGED=$(jq -r '.defaults.staleUnmergedDays // 21' "$REGISTRY")
  DEF_RECENCY=$(jq -r '.defaults.recencyGuardDays     // 2'    "$REGISTRY")
  DEF_DELETE_BRANCHES=$(jq -r '.defaults.deleteMergedBranches // true' "$REGISTRY")
fi

# --- trunk detection: registry/arg > develop > origin/HEAD > main/master ---
detect_trunk() {
  if [ -n "$TRUNK_ARG" ]; then echo "$TRUNK_ARG"; return; fi
  if [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]; then
    local t; t=$(jq -r '.trunk // empty' "$REGISTRY")
    [ -n "$t" ] && { echo "$t"; return; }
  fi
  for c in develop main master; do
    git show-ref --verify --quiet "refs/remotes/origin/$c" && { echo "$c"; return; }
    git show-ref --verify --quiet "refs/heads/$c"          && { echo "$c"; return; }
  done
  git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || echo main
}
TRUNK="$(detect_trunk)"
if git show-ref --verify --quiet "refs/remotes/origin/$TRUNK"; then
  TRUNKREF="origin/$TRUNK"
else
  TRUNKREF="$TRUNK"
fi

NOW=$(date +%s)
MAIN=$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -1)
REPO_SLUG=$(basename "$MAIN")

# today epoch at midnight — used only for snooze comparison
TODAY=$(date +%s)

git worktree list --porcelain | sed -n 's/^worktree //p' | while read -r WT; do
  HEAD=$(git -C "$WT" rev-parse HEAD 2>/dev/null || echo "")
  [ -z "$HEAD" ] && continue
  NAME=$(basename "$WT")

  if BR=$(git -C "$WT" symbolic-ref --quiet --short HEAD 2>/dev/null); then DETACHED=false; else BR=""; DETACHED=true; fi
  DIRTY=$(git -C "$WT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  BEHIND=0; AHEAD=0
  if OUT=$(git -C "$WT" rev-list --left-right --count "$TRUNKREF...HEAD" 2>/dev/null); then
    BEHIND=$(echo "$OUT" | awk '{print $1}'); AHEAD=$(echo "$OUT" | awk '{print $2}')
  fi

  if git -C "$WT" merge-base --is-ancestor HEAD "$TRUNKREF" 2>/dev/null; then MERGED=true; else MERGED=false; fi

  # pushed: tip reachable from some origin ref (work is safe on remote).
  # NB: use the hierarchical prefix 'refs/remotes/origin' — a '/*' glob does
  # NOT match nested names like origin/feature/foo.
  if [ -n "$(git -C "$WT" for-each-ref --contains "$HEAD" --format='x' refs/remotes/origin 2>/dev/null | head -1)" ]; then PUSHED=true; else PUSHED=false; fi

  # orphan: detached AND no branch/remote ref contains the tip (commits live nowhere else)
  ORPHAN=false
  if $DETACHED && [ -z "$(git -C "$WT" for-each-ref --contains "$HEAD" --format='x' refs/heads refs/remotes 2>/dev/null | head -1)" ]; then ORPHAN=true; fi

  LASTEPOCH=$(git -C "$WT" log -1 --format=%ct 2>/dev/null || echo "$NOW")
  AGEDAYS=$(( (NOW - LASTEPOCH) / 86400 ))
  LASTREL=$(git -C "$WT" log -1 --format=%cr 2>/dev/null || echo "unknown")

  SIZE_MB=0
  [ "$WANT_SIZE" = 1 ] && SIZE_MB=$(du -sm "$WT" 2>/dev/null | cut -f1)
  [ -z "$SIZE_MB" ] && SIZE_MB=0

  IS_MAIN=false; [ "$WT" = "$MAIN" ] && IS_MAIN=true

  # --- registry entry for this worktree (keyed by dir basename) ---
  KEEP="none"; NOTE=""; SNOOZE_ACTIVE=false
  if [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]; then
    KEEP=$(jq -r --arg n "$NAME" '.worktrees[$n].keep // "none" | if type=="object" then "snooze" else . end' "$REGISTRY")
    NOTE=$(jq -r --arg n "$NAME" '.worktrees[$n].note // ""' "$REGISTRY")
    if [ "$KEEP" = "snooze" ]; then
      UNTIL=$(jq -r --arg n "$NAME" '.worktrees[$n].keep.until // ""' "$REGISTRY")
      if [ -n "$UNTIL" ]; then
        UEPOCH=$(date -d "$UNTIL" +%s 2>/dev/null || echo 0)
        [ "$UEPOCH" -gt "$TODAY" ] && SNOOZE_ACTIVE=true
      fi
    fi
  fi

  # --- classify (priority order) ---
  VERDICT="KEEP"; KIND=""; REASON=""
  if $IS_MAIN; then
    VERDICT="KEEP"; KIND="primary"; REASON="primary worktree (never removed)"
  elif [ "$KEEP" = "always" ]; then
    VERDICT="KEEP"; KIND="pinned"; REASON="registry: keep=always"
  elif $SNOOZE_ACTIVE; then
    VERDICT="KEEP"; KIND="snoozed"; REASON="registry: snoozed until $UNTIL"
  elif [ "$AGEDAYS" -lt "$DEF_RECENCY" ]; then
    VERDICT="KEEP"; KIND="active"; REASON="active within ${DEF_RECENCY}d (last commit $LASTREL)"
  elif $ORPHAN; then
    VERDICT="ASK"; KIND="orphan"; REASON="detached HEAD, ${AHEAD} commit(s) in no branch/remote — removal orphans them"
  elif $MERGED && [ "$DIRTY" -eq 0 ] && [ "$AGEDAYS" -ge "$DEF_MERGED_AGE" ]; then
    VERDICT="AUTO_REMOVE"; KIND="merged-old"; REASON="merged into $TRUNK, clean, ${AGEDAYS}d old"
  elif $MERGED && [ "$DIRTY" -gt 0 ]; then
    VERDICT="ASK"; KIND="merged-dirty"; REASON="merged into $TRUNK but has $DIRTY uncommitted path(s)"
  elif $MERGED; then
    VERDICT="KEEP"; KIND="merged-young"; REASON="merged but only ${AGEDAYS}d old (< ${DEF_MERGED_AGE}d)"
  elif [ "$AGEDAYS" -ge "$DEF_STALE_UNMERGED" ]; then
    VERDICT="ASK"; KIND="stale-unmerged"; REASON="unmerged, idle ${AGEDAYS}d ($([ "$PUSHED" = true ] && echo 'branch safe on origin' || echo 'LOCAL-ONLY branch'))"
  else
    VERDICT="KEEP"; KIND="in-progress"; REASON="unmerged, in-progress (${AGEDAYS}d, < ${DEF_STALE_UNMERGED}d)"
  fi

  jq -nc \
    --arg name "$NAME" --arg path "$WT" --arg branch "$BR" \
    --argjson detached "$DETACHED" --argjson dirty "$DIRTY" \
    --argjson behind "$BEHIND" --argjson ahead "$AHEAD" \
    --argjson merged "$MERGED" --argjson pushed "$PUSHED" --argjson orphan "$ORPHAN" \
    --argjson ageDays "$AGEDAYS" --arg lastRel "$LASTREL" --argjson sizeMb "${SIZE_MB}" \
    --argjson isMain "$IS_MAIN" --arg keep "$KEEP" --arg note "$NOTE" \
    --arg verdict "$VERDICT" --arg kind "$KIND" --arg reason "$REASON" \
    '{name:$name,path:$path,branch:$branch,detached:$detached,dirty:$dirty,
      behind:$behind,ahead:$ahead,merged:$merged,pushed:$pushed,orphan:$orphan,
      ageDays:$ageDays,lastRel:$lastRel,sizeMb:$sizeMb,isMain:$isMain,
      keep:$keep,note:$note,verdict:$verdict,kind:$kind,reason:$reason}'
done | jq -s \
  --arg repo "$REPO_SLUG" --arg trunk "$TRUNK" \
  --argjson mergedAge "$DEF_MERGED_AGE" --argjson staleUnmerged "$DEF_STALE_UNMERGED" \
  --argjson recency "$DEF_RECENCY" --argjson delBranches "$DEF_DELETE_BRANCHES" \
  '{repo:$repo, trunk:$trunk,
    defaults:{mergedAgeDays:$mergedAge, staleUnmergedDays:$staleUnmerged, recencyGuardDays:$recency, deleteMergedBranches:$delBranches},
    worktrees:.}'
