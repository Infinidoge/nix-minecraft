{ callPackage
, lib
, our
, vanillaServers
}:

let
  versions = lib.importJSON ./locks.json;

  inherit (our.lib) escapeVersion latestVersion removeVanillaPrefix;
  latestLoaderVersion = latestVersion versions;
  createFabricServer = callPackage ./server.nix { inherit our vanillaServers; };

  packages =
      (lib.mapAttrs'
        (minecraftVersion: _:
          lib.nameValuePair
            "fabric-${escapeVersion minecraftVersion}"
            (lib.makeOverridable createFabricServer { inherit minecraftVersion; loaderVersion = latestLoaderVersion; }))
        (builtins.getAttr latestLoaderVersion versions));
in
packages
// { fabric = builtins.getAttr "fabric-${escapeVersion vanillaServers.vanilla.version}" packages; }
