# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

This is Harry's personal NixOS dotfiles repository for the system you are currently running on. It uses flakes for declarative system and user configuration.

## Configuration Architecture

The repository follows a flake-based structure with separation between system and user configurations:

- **nix/flake.nix**: Main entry point defining inputs and the `nixos` configuration output
- **nix/system/configuration.nix**: System-level configuration (bootloader, networking, users, system packages, services)
- **nix/system/hardware-configuration.nix**: Machine-specific hardware settings (this machine)
- **nix/home/common.nix**: Shared home-manager configuration for all users (Hyprland, development tools, desktop settings)
- **nix/home/home.nix**: Personal user (harry) specific configuration
- **nix/home/home-smartstation.nix**: Work user (harry-smartstation) specific configuration

The flake uses home-manager as a NixOS module, so user and system configurations rebuild together atomically.

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

This is equivalent to:
```bash
sudo nixos-rebuild switch --flake /home/harry/dotfiles/nix#nixos
```

Note: `~/nix` is a symlink to `~/dotfiles/nix`. The `rebuild` alias uses the absolute path so it works from both user accounts.

### Updating Dependencies

Update flake inputs to latest versions:
```bash
cd ~/nix
nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

### Testing Changes

Test without switching:
```bash
sudo nixos-rebuild test --flake ~/nix#nixos
```

Build without activating:
```bash
sudo nixos-rebuild build --flake ~/nix#nixos
```

## Workflow for Configuration Changes

1. Edit the appropriate .nix file:
   - System-level changes → `nix/system/configuration.nix`
   - Shared settings (both users) → `nix/home/common.nix`
   - Personal user only → `nix/home/home.nix`
   - Work user only → `nix/home/home-smartstation.nix`
   - New flake inputs → `nix/flake.nix`
2. Apply changes with `rebuild` alias
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
   - → Add to `environment.systemPackages` in **system/configuration.nix**

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
- System-level: `programs.*` in system/configuration.nix (e.g., `programs.git`)
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

Claude Code runs in a non-interactive environment and cannot directly execute commands that require password input via standard `sudo`.

### Solution: Use Konsole for Interactive Commands

When a command requires sudo password authentication, use Konsole to open a terminal window where the user can enter their password:

```bash
konsole -e bash -c "sudo COMMAND_HERE; echo; echo 'Press Enter to close...'; read" &
```

Example for nixos-rebuild:
```bash
konsole -e bash -c "sudo nixos-rebuild switch --flake ~/nix#nixos; echo; echo 'Press Enter to close...'; read" &
```

This approach:
- Opens a new Konsole terminal window
- Prompts for the sudo password in the terminal
- Keeps the window open after completion so the user can see the output
- Runs in the background so Claude Code can continue working
