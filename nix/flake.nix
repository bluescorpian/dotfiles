{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    claude-code.url = "github:sadjow/claude-code-nix";
  };

  outputs = { self, nixpkgs, home-manager, claude-code, ... } @ inputs:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {
     nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.harry = ./home/home.nix;

            # Pass inputs to home.nix for overlay access
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };
    };
  };
}
