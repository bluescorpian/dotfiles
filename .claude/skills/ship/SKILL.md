---
name: ship
description: Make a dotfiles change, rebuild the system so it takes effect, and commit it — the full edit → rebuild → commit loop in one go. Invoked with /ship <change>.
---

## Context

- Host: !`hostname`
- Status: !`git status --short`
- Recent commits (match their style): !`git log --oneline -5`

## Task

Make this change, then rebuild, then commit: **$ARGUMENTS**

### 1. Edit

Find the right `.nix` file and make the change (see CLAUDE.md for layout and conventions). Keep it surgical.

### 2. Rebuild

Aliases don't expand in `bash -c`, so run the full command:

```bash
sudo -A nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)
```

If the change only touches `nix/system/vps/`, rebuild the VPS instead:

```bash
nixos-rebuild switch --flake /home/shared/dotfiles/nix#vps --target-host harry@91.98.21.137 --sudo
```

If it fails, fix the error and retry. Don't commit a broken build — if you can't get it green, stop and report.

### 3. Commit

Stage **only the files you touched this session, by name** — the working tree usually has unrelated dirty files, never `git add -A`. Write a message matching the style above. Don't push.

Then report: what changed, that the rebuild succeeded, and what you committed.
