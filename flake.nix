{
  description = "An attempt to better support Minecraft-related content for the Nix ecosystem";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      ...
    }:
    let
      forEachSystem =
        fn:
        nixpkgs.lib.genAttrs (import systems) (
          system:
          fn (
            import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
              };
            }
          )
        );

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

      legacyPackages = forEachSystem (pkgs: import ./pkgs/all-packages.nix pkgs);

      packages = forEachSystem (
        pkgs:
        let
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
        {
          inherit (self.legacyPackages.${pkgs.stdenv.system})
            vanilla-server
            fabric-server
            quilt-server
            paper-server
            velocity-server
            minecraft-server
            nix-modrinth-prefetch
            ;

          docsAsciiDoc = docs.optionsAsciiDoc;
          docsCommonMark = docs.optionsCommonMark;
        }
      );

      checks = forEachSystem (
        pkgs: mkTests (pkgs.extend self.outputs.overlays.default) // self.packages.${pkgs.stdenv.system}
      );

      formatter = forEachSystem (pkgs: pkgs.nixfmt-rfc-style);
    };
}
