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
          vanillaServers = import ./pkgs/minecraft-servers { our = self; inherit (pkgs) lib callPackage javaPackages; };
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
        makeMinecraftServersFor (import nixpkgs { inherit system; config.allowUnfree = true; })
      );
    };
}
