{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    claude-code.url = "github:sadjow/claude-code-nix";
    nix-openclaw.url = "github:openclaw/nix-openclaw";
    claude-desktop.url = "github:aaddrick/claude-desktop-debian";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
    worktrunk.url = "github:max-sixty/worktrunk";
    worktrunk.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, plasma-manager, claude-code, claude-desktop, agenix, nix-openclaw, disko, vscode-server, worktrunk, ... } @ inputs:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pkgs-stable = nixpkgs-stable.legacyPackages.x86_64-linux;
  in
  {
     nixosConfigurations = {
      # Desktop configuration - personal computer with both users
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit pkgs-stable; };
        modules = [
          ./system/desktop/configuration.nix
          agenix.nixosModules.default
          # Apply claude-code and nix-openclaw overlays globally
          { nixpkgs.overlays = [ claude-code.overlays.default nix-openclaw.overlays.default claude-desktop.overlays.default ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.harry = ./home/home.nix;
            home-manager.users.harry-smartstation = ./home/home-smartstation.nix;
            home-manager.users.guest = ./home/home-guest.nix;
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
              nix-openclaw.homeManagerModules.openclaw
            ];
            home-manager.extraSpecialArgs = {
              inherit pkgs-stable;
              worktrunk-pkg = worktrunk.packages.x86_64-linux.default;
            };
          }
        ];
      };

      # VPS configuration - minimal headless server (stable channel)
      vps = nixpkgs-stable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { pkgs-unstable = nixpkgs.legacyPackages.x86_64-linux; };
        modules = [
          disko.nixosModules.disko
          vscode-server.nixosModules.default
          ./system/vps/configuration.nix
        ];
      };

      # Laptop configuration - work computer with both users
      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit pkgs-stable; };
        modules = [
          ./system/laptop/configuration.nix
          agenix.nixosModules.default
          # Apply claude-code and nix-openclaw overlays globally
          { nixpkgs.overlays = [ claude-code.overlays.default nix-openclaw.overlays.default claude-desktop.overlays.default ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.harry = ./home/home.nix;
            home-manager.users.harry-smartstation = ./home/home-smartstation.nix;
            home-manager.users.guest = ./home/home-guest.nix;
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
              nix-openclaw.homeManagerModules.openclaw
            ];
            home-manager.extraSpecialArgs = {
              inherit pkgs-stable;
              worktrunk-pkg = worktrunk.packages.x86_64-linux.default;
            };
          }
        ];
      };
    };
  };
}
