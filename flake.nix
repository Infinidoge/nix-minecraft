{
  description = "An attempt to better support Minecraft-related content for the Nix ecosystem";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    digga.url = "github:divnix/digga";
    digga.inputs.nixpkgs.follows = "nixpkgs";
    digga.inputs.nixlib.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , digga
    , ...
    }@inputs:
    digga.lib.mkFlake {
      inherit self inputs;

      channelsConfig = { allowUnfree = true; };

      sharedOverlays = [
        (final: prev: {
          __dontExport = true;
          lib = prev.lib.extend (lfinal: lprev: {
            our = self.lib;
          });
        })

        (final: prev: {
          lib = prev.lib.extend (lfinal: lprev: {
            maintainers = lprev.maintainers // {
              # Add myself as a maintainer
              infinidoge = {
                name = "Infinidoge";
                email = "infinidoge@inx.moe";
                github = "Infinidoge";
                githubId = 22727114;
              };
            };
          });
        })
      ];

      lib = import ./lib { lib = digga.lib // nixpkgs.lib; };

      outputsBuilder = channels:
        let
          pkgs = channels.nixpkgs;
          callPackage = pkgs.newScope { inherit inputs; };
        in
        {
          packages = rec {
            vanillaServers = callPackage ./pkgs/minecraft-servers { };
            fabricServers = callPackage ./pkgs/fabric-servers { inherit vanillaServers; };
            minecraftServers = vanillaServers // fabricServers;

            vanilla-server = vanillaServers.vanilla;
            fabric-server = fabricServers.fabric;
            minecraft-server = vanilla-server;
          } // (
            pkgs.lib.mapAttrs (n: v: callPackage v) (digga.lib.rakeLeaves ./pkgs/helpers)
          ) // (
            pkgs.lib.mapAttrs (n: v: callPackage v { }) (digga.lib.rakeLeaves ./pkgs/tools)
          );
        };

      overlay = final: prev: self.packages.x86_64-linux;

      nixosModules = digga.lib.rakeLeaves ./modules;
    };
}
