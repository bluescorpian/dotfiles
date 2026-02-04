# NixOS Multi-Machine Configuration

This repository contains a shared NixOS configuration supporting multiple machines with both personal and work user accounts.

## Current Machines

- **desktop**: Personal desktop with NVIDIA GPU
- **laptop**: Work laptop (configuration ready, hardware config to be generated on device)

## Repository Structure

```
nix/
├── flake.nix                          # Defines all machine configurations
├── system/
│   ├── common.nix                     # Shared system settings (all machines)
│   ├── desktop/
│   │   ├── configuration.nix          # Desktop-specific config
│   │   └── hardware-configuration.nix # Desktop hardware (auto-generated)
│   └── laptop/
│       ├── configuration.nix          # Laptop-specific config
│       └── hardware-configuration.nix # Laptop hardware (to be generated)
└── home/
    ├── common.nix                     # Shared user settings (both users)
    ├── home.nix                       # Personal user packages/config
    └── home-smartstation.nix          # Work user packages/config
```

## User Accounts

Both machines have two user accounts:
- **harry**: Personal user with entertainment apps (Discord, Spotify, etc.)
- **harry-smartstation**: Work user with minimal packages for work isolation

Both users share:
- Development tools and terminal utilities
- Desktop environment configuration
- File access via `harry-shared` group
- Shared directory at `/home/shared`

## Setting Up a New Device

### Prerequisites
- Fresh NixOS installation
- Internet connection
- Git installed

### Step-by-Step Setup

#### 1. Install NixOS
Install NixOS using the standard installer. During installation:
- Set hostname to match your configuration name (e.g., `laptop` for laptop config)
- Create a temporary user (you can use `harry` or `harry-smartstation`)
- Enable networking

#### 2. Clone Dotfiles Repository
```bash
cd ~
git clone https://github.com/bluescorpian/dotfiles.git
```

#### 3. Generate Hardware Configuration
Generate the hardware config for your specific machine:
```bash
sudo nixos-generate-config --show-hardware-config > ~/dotfiles/nix/system/<machine-name>/hardware-configuration.nix
```

Replace `<machine-name>` with your machine's hostname (e.g., `laptop`).

This detects:
- Filesystem UUIDs
- CPU type (Intel/AMD)
- Required kernel modules
- Swap devices
- Boot configuration

#### 4. Review Machine Configuration (Optional)
Check the machine-specific configuration file:
```bash
nano ~/dotfiles/nix/system/<machine-name>/configuration.nix
```

You may want to adjust:
- GPU drivers (NVIDIA, AMD, Intel)
- Power management (for laptops)
- Hardware-specific settings

#### 5. Apply Configuration
```bash
cd ~/dotfiles/nix
sudo nixos-rebuild switch --flake .#<machine-name>
```

Replace `<machine-name>` with your hostname (e.g., `desktop`, `laptop`).

#### 6. Set User Passwords
The configuration creates both user accounts. Set their passwords:
```bash
sudo passwd harry
sudo passwd harry-smartstation
```

#### 7. Create Convenience Symlink (Optional)
Link `~/nix` to `~/dotfiles/nix` for easier access:
```bash
ln -s ~/dotfiles/nix ~/nix
```

After this, you can use the `rebuild` alias from anywhere.

#### 8. Copy SSH Keys and Configuration
SSH keys are not managed by NixOS config and must be transferred manually.

**For each user account**, copy SSH files from your existing machine:

**Option A: Using USB Drive**
```bash
# On source machine (e.g., desktop)
cp -r ~/.ssh /path/to/usb/harry-ssh-backup

# On new machine (laptop)
mkdir -p ~/.ssh
cp -r /path/to/usb/harry-ssh-backup/* ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_* ~/.ssh/config 2>/dev/null || true
chmod 644 ~/.ssh/*.pub 2>/dev/null || true
```

**Option B: Using SCP (if both machines are on network)**
```bash
# On new machine
scp -r harry@desktop-ip:~/.ssh ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_* ~/.ssh/config 2>/dev/null || true
chmod 644 ~/.ssh/*.pub 2>/dev/null || true
```

**Option C: Generate New Keys**
If you prefer fresh keys, generate new ones and update them on GitHub/servers:
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Then add the new public key to GitHub, servers, etc.
```

**Important files to transfer:**
- `~/.ssh/id_*` - Private keys (KEEP SECURE!)
- `~/.ssh/id_*.pub` - Public keys
- `~/.ssh/config` - SSH client configuration (if customized)
- `~/.ssh/known_hosts` - Known server fingerprints (optional)

Repeat this process for both users (`harry` and `harry-smartstation`) if both need SSH access.

#### 9. Commit Hardware Config (Optional)
If you want to version control your hardware configuration:
```bash
cd ~/dotfiles
git add nix/system/<machine-name>/hardware-configuration.nix
git commit -m "Add <machine-name> hardware configuration"
git push
```

## Daily Usage

### Applying Configuration Changes

After editing any `.nix` file, apply changes with:
```bash
rebuild
```

This alias automatically detects your hostname and applies the correct configuration.

### Updating Dependencies

Update flake inputs to latest versions:
```bash
cd ~/nix
nix flake update
rebuild
```

### Testing Changes

Test without switching:
```bash
sudo nixos-rebuild test --flake ~/nix#$(hostname)
```

## Adding a New Machine

To add support for a new machine (e.g., a server or second laptop):

#### 1. Create Machine Directory
```bash
mkdir -p ~/dotfiles/nix/system/<new-machine-name>
```

#### 2. Create Machine Configuration
Create `~/dotfiles/nix/system/<new-machine-name>/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  # Set hostname
  networking.hostName = "<new-machine-name>";

  # Add machine-specific settings here
  # Examples: GPU drivers, power management, etc.

  # Define user accounts for this machine
  users.users.harry = {
    isNormalUser = true;
    description = "Harry Kruger";
    extraGroups = [ "networkmanager" "wheel" "harry-shared" "docker" "dialout" ];
    packages = with pkgs; [
      kdePackages.kate
      stow
    ];
  };

  users.users.harry-smartstation = {
    isNormalUser = true;
    description = "Harry (Work)";
    extraGroups = [ "networkmanager" "wheel" "harry-shared" "docker" "dialout" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };
}
```

#### 3. Create Placeholder Hardware Config
Create `~/dotfiles/nix/system/<new-machine-name>/hardware-configuration.nix`:

```nix
# PLACEHOLDER: Generate actual hardware config on the device using:
# sudo nixos-generate-config --show-hardware-config > ~/dotfiles/nix/system/<new-machine-name>/hardware-configuration.nix

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
```

#### 4. Update flake.nix
Add a new configuration entry in `~/dotfiles/nix/flake.nix`:

```nix
nixosConfigurations = {
  desktop = nixpkgs.lib.nixosSystem { ... };
  laptop = nixpkgs.lib.nixosSystem { ... };

  # Add new machine
  <new-machine-name> = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit pkgs-stable; };
    modules = [
      ./system/<new-machine-name>/configuration.nix
      { nixpkgs.overlays = [ claude-code.overlays.default ]; }
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.harry = ./home/home.nix;
        home-manager.users.harry-smartstation = ./home/home-smartstation.nix;
        home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
        home-manager.extraSpecialArgs = { inherit pkgs-stable; };
      }
    ];
  };
};
```

#### 5. Commit and Push
```bash
git add -A
git commit -m "Add configuration for <new-machine-name>"
git push
```

#### 6. Follow Setup Steps
On the new machine, follow the "Setting Up a New Device" steps above.

## Shared Configuration

### System-Level (common.nix)
- Bootloader (systemd-boot)
- Desktop environment (KDE Plasma 6)
- Audio (PipeWire)
- Networking (NetworkManager)
- Docker
- Git
- Common system packages

### User-Level (home/common.nix)
- Development tools (editors, compilers, runtimes)
- Terminal utilities
- Hyprland configuration
- Shell configuration

### Personal User (home/home.nix)
- Discord, Spotify
- Google Chrome
- Entertainment applications

### Work User (home/home-smartstation.nix)
- Minimal packages
- Work-specific tools only

## Troubleshooting

### "path does not exist" Error
If you get errors about paths not existing, ensure all files are tracked by git:
```bash
git add -A
git status
```
Flakes only include git-tracked files.

### "dirty tree" Warning
The warning is normal if you have uncommitted changes. It won't prevent rebuilds.

### Wrong Configuration Applied
The `rebuild` alias uses your hostname. Verify:
```bash
hostname
```
Should match a configuration name in `flake.nix`.

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [NixOS Search](https://search.nixos.org/)
