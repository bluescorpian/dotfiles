#!/usr/bin/env bash
# PreToolUse hook: remind the agent to resolve full session UUIDs before
# presenting them — claude-conversation-search returns 8-char prefixes only.
cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "claude-conversation-search returns 8-character session/message ID prefixes only. Before presenting any session ID to the user, resolve the full UUID: take the project path from the result, map it to ~/.claude/projects/<dir> (replace ~/ with -home-<user>- and every / with -), then run `ls ~/.claude/projects/<dir>/ | grep '^<prefix>'` and strip the .jsonl suffix. Never present a bare 8-character prefix as the session ID."
  }
}
JSON
