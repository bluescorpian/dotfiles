#!/usr/bin/env bash
# Claude Code notification hook - sends desktop notifications via notify-send

INPUT=$(cat)

NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type')
MESSAGE=$(echo "$INPUT" | jq -r '.message')
TITLE=$(echo "$INPUT" | jq -r '.title // "Claude Code"')
CWD=$(echo "$INPUT" | jq -r '.cwd')
PROJECT=$(basename "$CWD")

# Choose icon/urgency based on notification type
case "$NOTIFICATION_TYPE" in
  permission_prompt)
    URGENCY="normal"
    ICON="dialog-password"
    SUMMARY="Claude Code [$PROJECT] - Permission Needed"
    ;;
  idle_prompt)
    URGENCY="normal"
    ICON="dialog-information"
    SUMMARY="Claude Code [$PROJECT] - Waiting for Input"
    ;;
  auth_success)
    URGENCY="low"
    ICON="security-high"
    SUMMARY="Claude Code - Authenticated"
    ;;
  *)
    URGENCY="normal"
    ICON="dialog-information"
    SUMMARY="Claude Code [$PROJECT] - $TITLE"
    ;;
esac

notify-send -u "$URGENCY" -i "$ICON" -t 5000 "$SUMMARY" "$MESSAGE"
