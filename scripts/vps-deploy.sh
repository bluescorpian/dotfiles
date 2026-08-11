#!/usr/bin/env bash
#
# Deploy the VPS from the checkout that lives on the VPS.
#
# That checkout is the single source of truth for that host. Nothing pushes a
# built system at it from here any more — this script only tells it to pull and
# rebuild itself. The rule exists because there used to be two writers: this
# desktop deploying from /home/shared/dotfiles, and Hermes deploying from its
# own checkout. Whoever went last won, silently, and neither could see what the
# other had done. It fired in both directions in one afternoon — a desktop
# deploy would have removed packages Hermes had installed, and a stale Hermes
# deploy really did roll back Hermes' own root grant mid-task.
#
# So: edit here, commit, push, then run this. Or work on the box directly with
#   ssh vps sudo -u hermes -H claude -p "<task>" --dangerously-skip-permissions
#
# Everything touching the checkout runs as `hermes`. It is hermes-owned, and a
# file written by any other uid lands group-read-only under harry's 0022 umask,
# which would lock hermes out of editing its own repo — the ownership trap that
# has broken this service more than once already.
set -euo pipefail

REPO=/var/lib/hermes/workspace/dotfiles
BRANCH=hermes

# Heredoc deliberately unquoted so ${REPO}/${BRANCH} are interpolated here;
# anything that must evaluate on the far side is escaped (\$@, \$current).
# shellcheck disable=SC2087
ssh vps 'sudo bash -s' <<REMOTE
set -euo pipefail

as_hermes() { sudo -u hermes -H "\$@"; }

current=\$(as_hermes git -C ${REPO} rev-parse --abbrev-ref HEAD)
if [ "\$current" != "${BRANCH}" ]; then
  echo "checkout is on '\$current', expected '${BRANCH}' — refusing to deploy" >&2
  exit 1
fi

echo "==> fetching"
as_hermes git -C ${REPO} fetch --prune origin

echo "==> merging origin/main into ${BRANCH}"
as_hermes git -C ${REPO} merge --no-edit origin/main

if ! as_hermes git -C ${REPO} diff --quiet; then
  echo "note: working tree is dirty — deploying it as-is (path: copies the"
  echo "      directory, tracked or not). Probably Hermes mid-task."
  as_hermes git -C ${REPO} status --short
fi

echo "==> rebuilding"
# path: rather than a bare path: a bare path inside a git repo is fetched *as*
# a git repo, which hides untracked files and trips libgit2's ownership guard
# when root reads a hermes-owned checkout.
/run/current-system/sw/bin/nixos-rebuild switch --flake "path:${REPO}/nix#vps"
REMOTE

echo "==> done. Note that a dbus-broker reload timeout makes nixos-rebuild"
echo "    exit 4 over an activation that fully succeeded — check the output"
echo "    above rather than trusting the status code."
