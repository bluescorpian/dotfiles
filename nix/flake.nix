{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    claude-code.url = "github:sadjow/claude-code-nix";
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, claude-code, ... } @ inputs:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {
     nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/configuration.nix
          # Apply claude-code overlay globally
          { nixpkgs.overlays = [ claude-code.overlays.default ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.harry = ./home/home.nix;
            home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
          }
        ];
      };
    };
  };
}
