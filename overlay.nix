final: prev: {
  lib = prev.lib.extend (_: _: { our = import ./lib { lib = prev.lib; }; });
  mkTextileServer = final.callPackage ./pkgs/build-support/mkTextileServer.nix;
  mkTextileLoader = final.callPackage ./pkgs/build-support/mkTextileLoader.nix;
  vanillaServers = final.callPackage ./pkgs/vanilla-servers { };
  fabricServers = final.callPackage ./pkgs/fabric-servers { inherit (final) vanillaServers; };
  quiltServers = final.callPackage ./pkgs/quilt-servers { inherit (final) vanillaServers; };
  legacyFabricServers = final.callPackage ./pkgs/legacy-fabric-servers {
    inherit (final) vanillaServers;
  };
  paperServers = final.callPackage ./pkgs/paper-servers { inherit (final) vanillaServers; };
  velocityServers = final.callPackage ./pkgs/velocity-servers { };
  minecraftServers =
    final.vanillaServers
    // final.fabricServers
    // final.quiltServers
    // final.legacyFabricServers
    // final.paperServers;
  vanilla-server = final.vanillaServers.vanilla;
  fabric-server = final.fabricServers.fabric;
  quilt-server = final.quiltServers.quilt;
  paper-server = final.paperServers.paper;
  velocity-server = final.velocityServers.velocity;
  minecraft-server = final.vanilla-server;
  nix-modrinth-prefetch = final.callPackage ./pkgs/tools/nix-modrinth-prefetch.nix { };
  fetchPackwizModpack = final.callPackage ./pkgs/tools/fetchPackwizModpack { };
}
