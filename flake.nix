{
  description = "An attempt to better support Minecraft-related content for the Nix ecosystem";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    let
      mkTests =
        pkgs:
        let
          inherit (pkgs.stdenvNoCC) isLinux;
          inherit (pkgs.lib) optionalAttrs mapAttrs;
          callPackage = pkgs.newScope {
            inherit self;
            inherit (self) outputs;
            lib = pkgs.lib.extend (_: _: { our = self.lib; });
          };
        in
        optionalAttrs isLinux (mapAttrs (n: v: callPackage v { }) (self.lib.rakeLeaves ./tests));

      nixosModules = self.lib.rakeLeaves ./modules;
    in
    {
      lib = import ./lib { lib = nixpkgs.lib; };

      overlay = import ./overlay.nix;
      overlays.default = self.overlay;
      inherit nixosModules;

      hydraJobs = {
        checks = { inherit (self.checks) x86_64-linux; };
        packages = { inherit (self.packages) x86_64-linux; };
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
        docs = pkgs.nixosOptionsDoc {
          inherit
            (pkgs.lib.evalModules {
              modules = [
                { _module.check = false; }
                nixosModules.minecraft-servers
              ];
            })
            options
            ;
        };
      in
      rec {
        legacyPackages = import ./pkgs/all-packages.nix pkgs;

        packages = {
          inherit (legacyPackages)
            vanilla-server
            fabric-server
            quilt-server
            paper-server
            velocity-server
            minecraft-server
            nix-modrinth-prefetch
            neoforge-server
            ;

          docsAsciiDoc = docs.optionsAsciiDoc;
          docsCommonMark = docs.optionsCommonMark;
        };

        checks = mkTests (pkgs.extend self.outputs.overlays.default) // packages;

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
