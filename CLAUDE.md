# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

This is Harry's personal NixOS dotfiles repository. It lives at **`/home/shared/dotfiles`** so both user accounts can reach the same checkout, and uses flakes for declarative system and user configuration.

The flake defines three `nixosConfigurations`: **`desktop`**, **`laptop`**, and **`vps`**. The `rebuild` alias auto-selects the right one via `$(hostname)` — run `hostname` if you need to confirm which host you're on before rebuilding manually.

## Working Style

Treat this repo as a living system, not a museum piece. While working on a task, if you notice architectural smells — duplication across hosts, modules that have outgrown their file, stale abstractions, inconsistent naming, options that should be lifted into `common.nix` or pushed down into a host-specific file, services that would be cleaner as their own module — **say so**. Surface the observation as a short suggestion alongside the task at hand: what you noticed, why it matters, and a concrete refactor you'd propose. Do not silently implement large refactors; flag them and let the user decide whether to scope them in.

Bias toward raising these proactively rather than waiting to be asked. A one-line "by the way, X looks like it wants to move to Y because Z" is exactly the kind of feedback that's wanted.

## Configuration Architecture

The repository follows a flake-based structure with separation between system and user configurations:

- **nix/flake.nix**: Main entry point defining inputs and the `desktop`/`laptop`/`vps` nixosConfigurations
- **nix/system/common.nix**: Shared system config for desktop + laptop (display manager, audio, shell aliases including `rebuild`/`rebuild-vps`)
- **nix/system/desktop/configuration.nix**: Desktop-host system config
- **nix/system/desktop/hardware-configuration.nix**: Desktop hardware settings
- **nix/system/laptop/configuration.nix**: Laptop-host system config
- **nix/system/laptop/hardware-configuration.nix**: Laptop hardware settings
- **nix/home/common.nix**: Shared home-manager configuration for all users (Hyprland, development tools, desktop settings)
- **nix/home/home.nix**: Personal user (harry) specific configuration
- **nix/home/home-smartstation.nix**: Work user (harry-smartstation) specific configuration
- **nix/system/vps/configuration.nix**: VPS (Hetzner CX22) server configuration — independent from desktop/laptop
- **nix/system/vps/packages.nix**: VPS system packages and shell aliases
- **nix/system/vps/samba.nix**: Samba SMB share configuration
- **nix/system/vps/services/**: One file per self-hosted service (vaultwarden, cockpit, etc.)

The flake uses home-manager as a NixOS module, so user and system configurations rebuild together atomically.

> **Keep this section current.** When you add, rename, move, or remove a `.nix` file — or add/remove a host or service — update the file list above and any per-host references in the same change. Out-of-date architecture docs caused real rebuild failures (wrong path, wrong config name); fix it at the source instead of working around it.

### VPS Service Architecture

The VPS uses a modular pattern: one `.nix` file per service in `nix/system/vps/services/`.
Each service file is self-contained with its systemd service, Caddy virtual host, and port.

- Domain is defined as a variable (`domain = "hrry.sh"`) in `vps/configuration.nix` and passed via `_module.args`
- Service files accept `{ domain, ... }:` and use subdomains like `"app.${domain}"`
- Caddy handles reverse proxy and automatic HTTPS
- Port convention: use 3001+ range, increment per service
- VPS runs on `nixpkgs-stable`, with `pkgs-unstable` available via `specialArgs` for specific packages
- To add a new service: create `services/foo.nix`, add import to `configuration.nix`

### User Accounts

The system has two user accounts for work/personal isolation:

- **harry**: Personal user account
  - Packages: Discord, Spotify, Google Chrome, entertainment apps

- **harry-smartstation**: Work user account
  - Packages: Development tools only (minimal, no social/entertainment apps)

Both users share:
- Development tools
- Hyprland configuration and keybindings
- Desktop environment settings
- File access via `harry-shared` group
- Shared directory: `/home/shared` (group writable with setgid bit)

## Essential Commands

### Applying Configuration Changes

After editing any .nix file, use the system-wide alias:
```bash
rebuild
```

For the VPS (remote deployment):
```bash
rebuild-vps
```

The `rebuild` alias is defined in `nix/system/common.nix` and resolves to:
```bash
sudo nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)
```

So on the laptop it builds `#laptop`, on the desktop it builds `#desktop`. Both users share the same checkout at `/home/shared/dotfiles` (group-readable via `harry-shared`), which is why the alias hard-codes that absolute path.

### Updating Dependencies

Update flake inputs to latest versions:
```bash
cd /home/shared/dotfiles/nix
nix flake update
rebuild
```

### Testing Changes

Test without switching (also aliased as `rebuild-test`):
```bash
sudo nixos-rebuild test --flake /home/shared/dotfiles/nix#$(hostname)
```

Build without activating:
```bash
sudo nixos-rebuild build --flake /home/shared/dotfiles/nix#$(hostname)
```

## Workflow for Configuration Changes

1. Edit the appropriate .nix file:
   - System-level changes shared by desktop+laptop → `nix/system/common.nix`
   - Host-specific system changes → `nix/system/desktop/configuration.nix` or `nix/system/laptop/configuration.nix`
   - Shared home-manager settings (both users) → `nix/home/common.nix`
   - Personal user only → `nix/home/home.nix`
   - Work user only → `nix/home/home-smartstation.nix`
   - New flake inputs → `nix/flake.nix`
   - VPS server changes → `nix/system/vps/configuration.nix`
   - New VPS service → create `nix/system/vps/services/<name>.nix` and add import
2. Apply changes with `rebuild` alias (or `rebuild-vps` for the server)
3. Commit to git and push to backup

## Git Workflow for Configuration Snapshots

Git commits serve as snapshots of your NixOS configuration, allowing you to track changes and roll back if needed.

### When to Commit

- **After successful changes**: Once you've tested a configuration change with `nixos-rebuild switch` and verified it works
- **Before major experiments**: Commit your working state before trying significant changes
- **Atomic commits**: Each commit should represent one logical change (e.g., "Add Spotify", not "Update various things")

### Commit Best Practices

1. **Test first**: Always run `nixos-rebuild switch` and verify the system works before committing
2. **Descriptive messages**: Write clear commit messages that explain what changed
   - Good: "Add Spotify and configure PipeWire EQ"
   - Poor: "Update config"
3. **Push regularly**: Keep your remote backup current in case of hardware failure

## Adding Packages or Programs

### Deciding: Where to Add Packages

Use this decision tree to determine where a package belongs:

1. **Does it require system-level privileges or is it a system service?**
   - Examples: networking tools, display managers, bootloaders, drivers, system daemons
   - → Add to `environment.systemPackages` in **system/common.nix** (both hosts) or the relevant host's **system/<host>/configuration.nix**

2. **Should it be available to both users?**
   - Examples: development tools (editors, language runtimes), terminal utilities
   - → Add to `home.packages` in **home/common.nix**

3. **Is it personal/entertainment only?**
   - Examples: Discord, Spotify, games
   - → Add to `home.packages` in **home/home.nix** (personal user only)

4. **Is it work-specific?**
   - Examples: work-specific clients, enterprise tools
   - → Add to `home.packages` in **home/home-smartstation.nix** (work user only)

5. **When in doubt**: Add to **home/common.nix** for shared access

### Using Program Modules

Many packages have declarative configuration modules:
- System-level: `programs.*` in system/common.nix or system/<host>/configuration.nix (e.g., `programs.git`)
- User-level: `programs.*` in home/home.nix (e.g., `programs.kitty`, `programs.plasma`)

When a program module exists, prefer using it over just adding the package, as it provides better integration and declarative configuration.

## Research and Documentation

When researching NixOS configuration options or system behavior, use the locally installed documentation:

### NixOS Manual (HTML)
Read the full NixOS manual using the Read tool:
```
/run/current-system/sw/share/doc/nixos/index.html
```

### NixOS Options Reference (HTML)
Search all available configuration options:
```
/run/current-system/sw/share/doc/nixos/options.html
```

Note: This file is large (23MB). Use the Read tool with grep/search when looking for specific options.

### Configuration Man Page
For a comprehensive reference of configuration options:
```bash
man configuration.nix
```

### Linux Manual Pages
Use `man` for system commands and utilities:
```bash
man <command>
```

Always check local documentation first before searching online, as it matches this system's NixOS version and available options.

## Running Commands That Require sudo

Claude Code's Bash subshells have no TTY, so plain `sudo` can't prompt for a password. The system is configured so `sudo -A` routes the prompt through a GUI dialog (`ksshaskpass`) instead, while keeping stdout/stderr/exit code wired back to the calling shell. Run sudo commands directly and read their output, the way you would any other Bash call:

```bash
sudo -A nixos-rebuild switch --flake /home/shared/dotfiles/nix#$(hostname)
```

A small Qt password dialog pops up on the user's desktop. They type the password, hit Enter, and the command runs in the same Bash invocation — output streams back normally. Sudo's timestamp cache covers subsequent `sudo -A` calls within a few minutes without re-prompting.

If no graphical session is available (pure SSH/TTY login), fall back to konsole — but in that mode the output is not visible to Claude:

```bash
konsole -e bash -c "sudo COMMAND_HERE; echo; echo 'Press Enter to close...'; read" &
```
