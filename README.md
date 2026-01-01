# My NixOS Config

Quick reference for restoring my setup on a new machine.

## Fresh Install Steps

1. **Install base NixOS** from ISO

2. **Enable flakes** - Add to `/etc/nixos/configuration.nix`:
   ```nix
   nix.settings.experimental-features = [ "nix-command" "flakes" ];
   ```
   Then: `sudo nixos-rebuild switch`

3. **Clone dotfiles**:
   ```bash
   cd ~
   git clone <this-repo-url> dotfiles
   ln -s ~/dotfiles/nix ~/nix
   ```

4. **Generate new hardware config**:
   ```bash
   sudo nixos-generate-config --show-hardware-config > ~/dotfiles/nix/system/hardware-configuration.nix
   ```

5. **Apply config**:
   ```bash
   sudo nixos-rebuild switch --flake ~/dotfiles/nix#nixos
   ```

## Daily Use

**Rebuild after changes**:
```bash
sudo nixos-rebuild switch --flake ~/nix#nixos
```

**Update everything**:
```bash
cd ~/nix
nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

**Backup changes**:
```bash
cd ~/dotfiles
git add .
git commit -m "Update config"
git push
```
