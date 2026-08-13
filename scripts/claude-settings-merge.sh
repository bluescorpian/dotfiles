#!/usr/bin/env bash
# Merge an untracked per-machine overlay into ~/.claude/settings.json.
#
# Why this exists: Claude Code's auto-mode classifier reads its `autoMode` block
# only from ~/.claude/settings.json or managed settings — never from a project's
# .claude/settings.json or settings.local.json. This repo is public, so work
# identifiers (client/org names, cloud profiles and regions, internal hostnames)
# can't live in claude/settings.json. They go in an untracked overlay instead,
# and this script splices the two together.
#
# Objects merge; the four autoMode rule arrays and the three permissions arrays
# concatenate rather than replace. Only non-empty results are written back, and
# the public base seeds every rule array with "$defaults" — an autoMode array
# that lacks it replaces that entire built-in list, so an overlay-only
# `soft_deny` would silently drop all ~65 built-in classifier rules.
#
# Called from home-manager activation (nix/home/common.nix) with an explicit
# store path, and available standalone as `claude-settings-sync` for when only
# the overlay changed — nix can't see that file, so a rebuild alone won't
# re-run the merge.
set -euo pipefail

BASE=${1:-/home/shared/dotfiles/claude/settings.json}
OVERLAY=${2:-$HOME/.config/claude-code-local/overlay.json}
TARGET=${3:-$HOME/.claude/settings.json}
JQ=${JQ:-jq}

[ -f "$BASE" ] || { echo "claude-settings-merge: no base at $BASE" >&2; exit 1; }

if [ ! -f "$OVERLAY" ]; then
  install -m600 "$BASE" "$TARGET"
  exit 0
fi

tmp=$(mktemp "$TARGET.XXXXXX")
trap 'rm -f "$tmp"' EXIT

if "$JQ" -n --slurpfile base "$BASE" --slurpfile ovl "$OVERLAY" '
      def cat($a; $b): (($a // []) + ($b // []));
      ($base[0]) as $b | ($ovl[0]) as $o |
      reduce ([
        ["autoMode","environment"], ["autoMode","allow"],
        ["autoMode","soft_deny"],   ["autoMode","hard_deny"],
        ["permissions","allow"],    ["permissions","ask"],
        ["permissions","deny"]
      ] | .[]) as $p (($b * $o);
        cat($b | getpath($p); $o | getpath($p)) as $v
        | if ($v | length) > 0 then setpath($p; $v) else . end)
      | del(._comment)
    ' > "$tmp"; then
  install -m600 "$tmp" "$TARGET"
else
  echo "claude-settings-merge: overlay merge failed, installing base only" >&2
  install -m600 "$BASE" "$TARGET"
fi
