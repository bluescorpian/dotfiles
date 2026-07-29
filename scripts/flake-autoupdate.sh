#!/usr/bin/env bash
#
# Update flake inputs, rebuild, and commit the result locally (never pushes —
# review with `git show`/`git log` and push yourself).
#
# On a failed rebuild, hands off to a headless Claude Code session that
# triages the break, applies a minimal fix, and re-verifies by rebuilding
# itself before handing back control. The outer script independently
# re-runs the rebuild afterwards rather than trusting Claude's self-report.
#
# Usage: flake-autoupdate.sh [nix flake update args...]
#   flake-autoupdate.sh                 # update every input
#   flake-autoupdate.sh claude-code     # update a single input

set -euo pipefail

REPO="/home/shared/dotfiles"
FLAKE_DIR="$REPO/nix"
HOST="$(hostname)"
WORK="$(mktemp -d -t flake-autoupdate.XXXXXX)"
BUILD_LOG="$WORK/rebuild.log"
CLAUDE_LOG="$WORK/claude.json"

cleanup() {
  local status=$?
  if (( status == 0 )); then
    rm -rf "$WORK"
  else
    echo "==> Logs kept at $WORK for debugging." >&2
  fi
}
trap cleanup EXIT

cd "$REPO"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty — commit or stash your changes first:" >&2
  git status --short >&2
  exit 1
fi

rebuild() {
  sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"
}

# Cheap defense-in-depth before an unattended commit on a public repo — not a
# real secret scanner, just catches the obvious stuff (private keys, common
# API token shapes).
secrets_in_staged() {
  git diff --cached | grep -inE \
    'BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]+|-----BEGIN CERTIFICATE-----'
}

echo "==> Updating flake inputs ($FLAKE_DIR)..."
UPDATE_OUTPUT="$(nix flake update --flake "$FLAKE_DIR" "$@" 2>&1)" || {
  echo "$UPDATE_OUTPUT" >&2
  echo "error: 'nix flake update' itself failed — not attempting a rebuild." >&2
  exit 1
}
echo "$UPDATE_OUTPUT"

if git diff --quiet -- "$FLAKE_DIR/flake.lock"; then
  echo "==> flake.lock unchanged, nothing to do."
  exit 0
fi

echo "==> Rebuilding $HOST..."
if rebuild 2>&1 | tee "$BUILD_LOG"; then
  git add "$FLAKE_DIR/flake.lock"
  git commit -q -m "chore(flake): update inputs" -m "$UPDATE_OUTPUT"
  echo "==> Rebuild OK. Committed locally as $(git rev-parse --short HEAD) — review and push when ready."
  exit 0
fi

echo "==> Rebuild failed. Handing off to headless Claude Code for triage..." >&2

PROMPT="$(cat <<EOF
Harry's NixOS dotfiles repo at $REPO (flake at $FLAKE_DIR, host "$HOST").

I just ran 'nix flake update' then 'sudo nixos-rebuild switch --flake $FLAKE_DIR#$HOST'
and the rebuild failed. flake.lock has already been updated by the flake update
but nothing is committed yet. Full build log: $BUILD_LOG

Diagnose why the rebuild broke and make the minimal fix needed to get it
building and switching again — e.g. an option renamed/removed upstream, a
package attribute that moved. If one specific flake input is the culprit,
prefer pinning back JUST that input (git checkout HEAD -- $FLAKE_DIR/flake.lock,
then 'nix flake lock --update-input <name>' for the others you still want) over
reverting the whole update. Don't touch other hosts, don't refactor, don't
change anything beyond what's needed to unbreak this build.

Verify your own fix by actually re-running:
  sudo nixos-rebuild switch --flake $FLAKE_DIR#$HOST
sudo should still have a cached credential from my earlier attempt. Iterate
until it switches cleanly. If you don't think it's fixable within reason, stop
and explain why instead of guessing further — don't leave the tree in a
half-edited state.

Do NOT git add, commit, or push anything — I handle committing after
independently re-verifying your fix.

End your final message with a short paragraph summarizing what broke and what
you changed, suitable as a commit message body.
EOF
)"

CLAUDE_OK=1
timeout 30m claude -p "$PROMPT" \
  --model sonnet \
  --permission-mode auto \
  --allowedTools "Bash Read Edit Grep Glob" \
  --output-format json \
  > "$CLAUDE_LOG" || CLAUDE_OK=0

if SUMMARY="$(jq -r '.result' "$CLAUDE_LOG" 2>/dev/null)" && [[ -n "$SUMMARY" && "$SUMMARY" != "null" ]]; then
  :
else
  SUMMARY="(no summary available — see $CLAUDE_LOG)"
fi
IS_ERROR="$(jq -r '.is_error // true' "$CLAUDE_LOG" 2>/dev/null || echo true)"

echo "==> Claude's summary:"
echo "$SUMMARY"

if [[ "$CLAUDE_OK" != 1 || "$IS_ERROR" == true ]]; then
  echo "error: headless Claude session aborted or errored — see $CLAUDE_LOG. Tree left as-is." >&2
  exit 1
fi

echo "==> Re-verifying rebuild after Claude's fix..."
if ! rebuild 2>&1 | tee -a "$BUILD_LOG"; then
  echo "error: still broken after Claude's fix. Leaving changes uncommitted — see $BUILD_LOG / $CLAUDE_LOG." >&2
  git status --short >&2
  exit 1
fi

git add -A -- "$FLAKE_DIR"
echo "==> Staged changes:"
git diff --cached --stat

if secrets_in_staged; then
  echo "error: staged diff matches a secret-looking pattern — refusing to auto-commit. Review by hand:" >&2
  secrets_in_staged >&2
  exit 1
fi

git commit -q -m "fix(flake): repair rebuild after flake update" -m "$SUMMARY"
echo "==> Rebuild verified and fix committed locally as $(git rev-parse --short HEAD) — review and push when ready."
