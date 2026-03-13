{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    htop
  ];

  environment.shellAliases = {
    rebuild = "nixos-rebuild switch --flake /home/harry/dotfiles/nix#vps";
  };
}
