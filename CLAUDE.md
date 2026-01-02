# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

This is Harry's personal NixOS dotfiles repository for the system you are currently running on. It uses flakes for declarative system and user configuration.

## Configuration Architecture

The repository follows a flake-based structure with separation between system and user configurations:

- **nix/flake.nix**: Main entry point defining inputs and the `nixos` configuration output
- **nix/system/configuration.nix**: System-level configuration (bootloader, networking, users, system packages, services)
- **nix/system/hardware-configuration.nix**: Machine-specific hardware settings (this machine)
- **nix/home/home.nix**: User-level configuration using home-manager (user packages, desktop settings, window manager configs)

The flake uses home-manager as a NixOS module, so user and system configurations rebuild together atomically.

## Essential Commands

### Applying Configuration Changes

After editing any .nix file:
```bash
sudo nixos-rebuild switch --flake ~/nix#nixos
```

Note: `~/nix` is a symlink to `~/dotfiles/nix`

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
   - User-level changes → `nix/home/home.nix`
   - New flake inputs → `nix/flake.nix`
2. Apply changes with `nixos-rebuild switch`
3. Commit to git and push to backup

## Adding Packages or Programs

### Deciding: System vs User Configuration

Use this decision tree to determine where a package belongs:

1. **Does it require system-level privileges or is it a system service?**
   - Examples: networking tools, display managers, bootloaders, drivers, system daemons
   - → Add to `environment.systemPackages` in **system/configuration.nix**

2. **Is it a user application or tool?**
   - Examples: browsers, editors, CLI tools, desktop applications
   - → Add to `home.packages` in **home/home.nix**

3. **Does it need to be available system-wide or for all users?**
   - Examples: development tools needed at login, system utilities
   - → Add to **system/configuration.nix**

4. **When in doubt**: Prefer **home/home.nix** for single-user systems

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
