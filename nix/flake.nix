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
    # Pin kitty to 0.48.0: 0.48.1 aborts the whole process when you drag a tab out
    # of the tab bar. Its new drag_icon_surface_listener registers only .enter/.leave,
    # but wl_compositor is bound at version 6 whenever the compositor offers it (sway
    # 1.12 does), so the drag icon surface gets wl_surface.preferred_buffer_scale
    # (opcode 2) and libwayland aborts on the NULL listener slot:
    #   listener function for opcode 2 of wl_surface is NULL
    # Fixed upstream in kitty 0.48.2 (commit 16da653, kovidgoyal/kitty#10284), which
    # nixpkgs hasn't picked up yet. 0.48.0 predates the listener entirely, so it has
    # no such crash path. Drop this input once unstable ships >= 0.48.2.
    nixpkgs-kitty.url = "github:nixos/nixpkgs/6d12004108e0e4a5cfa4bd83b14477f040b15773";
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
    # Harry's portfolio over SSH, which the VPS serves (system/vps/services/hrry-sh.nix).
    # Following nixpkgs-stable rather than nixpkgs: the VPS is the only consumer
    # and it is a stable host, so this builds the daemon against the same package
    # set everything else there is built from instead of pulling a second Go
    # toolchain and a second nixpkgs eval onto the box.
    # git+ssh rather than github: the repo is private, so the box fetches it with
    # a read-only deploy key at /root/.ssh/id_ed25519 (see system/vps/CLAUDE.md).
    # Deploys evaluate as root, which is whose key that has to be.
    hrry-sh.url = "git+ssh://git@github.com/bluescorpian/hrry.sh?ref=main";
    hrry-sh.inputs.nixpkgs.follows = "nixpkgs-stable";
    elephant.url = "github:abenz1267/elephant";
    walker.url = "github:abenz1267/walker";
    walker.inputs.elephant.follows = "elephant";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-logseq, nixpkgs-kitty, home-manager, plasma-manager, claude-code, claude-desktop, agenix, disko, vscode-server, worktrunk, walker, hermes-agent, hrry-sh, ... } @ inputs:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pkgs-stable = nixpkgs-stable.legacyPackages.x86_64-linux;
    logseq-pkg = nixpkgs-logseq.legacyPackages.x86_64-linux.logseq;
    kitty-pkg = nixpkgs-kitty.legacyPackages.x86_64-linux.kitty;
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
              inherit pkgs-stable logseq-pkg kitty-pkg;
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
          hrry-sh.nixosModules.default
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
              inherit pkgs-stable logseq-pkg kitty-pkg;
              worktrunk-pkg = worktrunk.packages.x86_64-linux.default;
            };
          }
        ];
      };
    };
  };
}
