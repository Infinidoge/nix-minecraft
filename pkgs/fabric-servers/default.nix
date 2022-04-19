{ callPackage
, lib
, vanillaServers
}:

let
  versions = lib.importJSON ./locks.json;

  merge = null;

  inherit (lib.our) escapeVersion;
  latestVersion = escapeVersion (lib.our.latestVersion versions);

  packages =
    builtins.foldl' (x: y: x // y) { }
      (lib.mapAttrsToList
        (lversion: gversions:
          lib.mapAttrs'
            (gversion: lock:
              lib.nameValuePair
                "fabric-${escapeVersion gversion}-${escapeVersion lversion}"
                (callPackage ./server.nix { inherit lock; minecraft-server = vanillaServers."vanilla-${escapeVersion gversion}"; }))
            gversions)
        versions);
in
lib.recurseIntoAttrs (
  packages
  // (
    let
      removeVanilla = n: escapeVersion (lib.removePrefix "vanilla-" n);
    in
    (lib.mapAttrs'
      (n: v: lib.nameValuePair "fabric-${lib.removePrefix "vanilla-" n}" v)
      (lib.genAttrs
        (builtins.filter
          (n: (lib.hasPrefix "vanilla-" n) && (builtins.hasAttr "fabric-${removeVanilla n}-${latestVersion}" packages))
          (builtins.attrNames vanillaServers))
        (gversion: builtins.getAttr "fabric-${removeVanilla gversion}-${latestVersion}" packages)))
  ) // {
    fabric = builtins.getAttr "fabric-${escapeVersion vanillaServers.vanilla.version}-${latestVersion}" packages;
  }
)
