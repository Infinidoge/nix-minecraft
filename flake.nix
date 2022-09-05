{
  description = "An attempt to better support Minecraft-related content for the Nix ecosystem";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      makeMinecraftServersFor = (pkgs:
        let
          vanillaServers = import ./pkgs/vanilla-servers { our = self; inherit (pkgs) lib callPackage jre8_headless jre_headless; };
        in
        vanillaServers
        // import ./pkgs/fabric-servers { our = self; inherit vanillaServers; inherit (pkgs) lib callPackage; }
        // import ./pkgs/quilt-servers { our = self; inherit vanillaServers; inherit (pkgs) lib callPackage; }
      );
    in
    {
      lib = import ./lib { inherit (nixpkgs) lib; };
      overlays.default = (final: prev: {
        nix-minecraft = prev.lib.recurseIntoAttrs (makeMinecraftServersFor prev);
      });
      nixosModules.minecraft-servers = import ./modules/minecraft-servers.nix;
      packages = forAllSystems (system:
        makeMinecraftServersFor (import nixpkgs {
          inherit system;
          # Every package in this repo is unfree, using this repo you accept that you will be using unfree packages.
          config.allowUnfree = true;
          # JRE cannot compile without these packages currently: https://github.com/NixOS/nixpkgs/issues/170825
          config.permittedInsecurePackages = [
            "openjdk-headless-16+36"
            "openjdk-headless-15.0.1-ga"
            "openjdk-headless-14.0.2-ga"
            "openjdk-headless-13.0.2-ga"
            "openjdk-headless-12.0.2-ga"
          ];
        })
      );
      checks.x86_64-linux =
        let
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};
          mkTest = minecraft-package: (import ./tests/minecraft-servers.nix {
            makeTest = import (nixpkgs + "/nixos/tests/make-test-python.nix");
            nixosModule = self.nixosModules.minecraft-servers;
            inherit pkgs minecraft-package;
          }).minecraft-server-test;
        in
        {
          vanilla = mkTest self.packages.${system}.vanilla;
          fabric = mkTest self.packages.${system}.fabric;
          fabric-with-override = mkTest (self.packages.${system}.fabric-1_14.override { loaderVersion = "0.13.0"; });
          quilt = mkTest self.packages.${system}.quilt;
        };
    };
}
