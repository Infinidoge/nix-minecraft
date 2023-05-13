{
  description = "An attempt to better support Minecraft-related content for the Nix ecosystem";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }@inputs:
    let
      mkPackages = pkgs:
        let
          callPackage = pkgs.newScope {
            inherit inputs;
            lib = pkgs.lib.extend (_: _: { our = self.lib; });
          };
        in
        rec {
          vanillaServers = callPackage ./pkgs/vanilla-servers { };
          fabricServers = callPackage ./pkgs/fabric-servers { inherit vanillaServers; };
          quiltServers = callPackage ./pkgs/quilt-servers { inherit vanillaServers; };
          legacyFabricServers = callPackage ./pkgs/legacy-fabric-servers { inherit vanillaServers; };
          paperServers = callPackage ./pkgs/paper-servers { };
          velocityServers = callPackage ./pkgs/velocity-servers { };
          minecraftServers = vanillaServers // fabricServers // quiltServers // legacyFabricServers // paperServers;

          vanilla-server = vanillaServers.vanilla;
          fabric-server = fabricServers.fabric;
          quilt-server = quiltServers.quilt;
          paper-server = paperServers.paper;
          velocity-server = velocityServers.velocity;
          minecraft-server = vanilla-server;
        } // (
          builtins.mapAttrs (n: v: callPackage v { }) (self.lib.rakeLeaves ./pkgs/tools)
        );
    in
    {
      lib = import ./lib { lib = flake-utils.lib // nixpkgs.lib; };

      overlay = final: prev: mkPackages prev;
      overlays.default = self.overlay;
      nixosModules = self.lib.rakeLeaves ./modules;
    } // flake-utils.lib.eachDefaultSystem (system: rec {
      legacyPackages = mkPackages (import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      });

      packages = {
        inherit (legacyPackages)
          vanilla-server
          fabric-server
          quilt-server
          paper-server
          velocity-server
          minecraft-server
          nix-modrinth-prefetch;
      };
    });
}
