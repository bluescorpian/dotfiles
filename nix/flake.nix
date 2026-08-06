{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    # Pin logseq to 0.10.14: unstable's 0.10.15 isn't in the binary cache (builds
    # the ClojureScript/Electron app from source, appears to hang) and bumped to
    # the EOL-flagged Electron 39. This commit ships 0.10.14 on Electron 38.7.1 —
    # cached (~60 MB DL) and not flagged insecure. Bump when unstable's logseq is
    # cached again. Only used for the logseq package (see home/common.nix).
    nixpkgs-logseq.url = "github:nixos/nixpkgs/ea30586ee015f37f38783006a9bc9e4aa64d7d61";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-desktop.url = "github:aaddrick/claude-desktop-debian";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
    worktrunk.url = "github:max-sixty/worktrunk";
    worktrunk.inputs.nixpkgs.follows = "nixpkgs";
    # Deliberately not `follows`-ing our nixpkgs: the package set is built by
    # uv2nix against the exact nixpkgs it pins, and repointing it is a good way
    # to break the Python dependency closure. Costs one extra nixpkgs eval.
    hermes-agent.url = "github:NousResearch/hermes-agent";
    elephant.url = "github:abenz1267/elephant";
    walker.url = "github:abenz1267/walker";
    walker.inputs.elephant.follows = "elephant";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-logseq, home-manager, plasma-manager, claude-code, claude-desktop, agenix, disko, vscode-server, worktrunk, walker, hermes-agent, ... } @ inputs:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pkgs-stable = nixpkgs-stable.legacyPackages.x86_64-linux;
    logseq-pkg = nixpkgs-logseq.legacyPackages.x86_64-linux.logseq;

    # Same package set the VPS consumes at runtime. This dev shell is for
    # manual investigation; Hermes itself receives this runtime through
    # services.hermes-agent.extraPackages (see services/hermes.nix).
    hermes-skill-runtime = import ./packages/hermes-runtime.nix { pkgs = pkgs-stable; };
  in
  {
    devShells.x86_64-linux.default = pkgs-stable.mkShell {
      packages = hermes-skill-runtime.packages;
    };

     nixosConfigurations = {
      # Desktop configuration - personal computer with both users
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit pkgs-stable; };
        modules = [
          ./system/desktop/configuration.nix
          agenix.nixosModules.default
          # Apply claude-code and claude-desktop overlays globally
          { nixpkgs.overlays = [ claude-code.overlays.default claude-desktop.overlays.default ]; }
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
              walker.homeManagerModules.default
            ];
            home-manager.extraSpecialArgs = {
              inherit pkgs-stable logseq-pkg;
              worktrunk-pkg = worktrunk.packages.x86_64-linux.default;
            };
          }
        ];
      };

      # VPS configuration - minimal headless server (stable channel)
      vps = nixpkgs-stable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          pkgs-unstable = nixpkgs.legacyPackages.x86_64-linux;
          # Hermes drives the `claude` CLI (see services/hermes.nix), and wants
          # a current one: stable 26.05 ships 2.1.187 against this flake's
          # 2.1.222. Taken as a flake *output* rather than via the overlay
          # desktop and laptop apply — deliberately. Applying the overlay to
          # this host would rebuild claude-code against stable nixpkgs, landing
          # on a store path that exists in no binary cache (verified: 404 on
          # both cache.nixos.org and claude-code.cachix.org), so every deploy
          # would build it from source and push 354 MiB up the uplink. The
          # flake output is the identical path the desktop already runs and is
          # cached, so the VPS substitutes it directly.
          claude-code-pkg = claude-code.packages.x86_64-linux.default;
        };
        modules = [
          disko.nixosModules.disko
          vscode-server.nixosModules.default
          hermes-agent.nixosModules.default
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
          # Apply claude-code and claude-desktop overlays globally
          { nixpkgs.overlays = [ claude-code.overlays.default claude-desktop.overlays.default ]; }
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
              walker.homeManagerModules.default
            ];
            home-manager.extraSpecialArgs = {
              inherit pkgs-stable logseq-pkg;
              worktrunk-pkg = worktrunk.packages.x86_64-linux.default;
            };
          }
        ];
      };
    };
  };
}
