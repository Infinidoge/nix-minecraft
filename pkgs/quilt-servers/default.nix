{ callPackage
, lib
, our
, vanillaServers
}:

let
  versions = lib.importJSON ./locks.json;

  inherit (our.lib) escapeVersion removeVanillaPrefix;
  latestVersion = escapeVersion (our.lib.latestVersion versions);

  packages =
    builtins.foldl' (x: y: x // y) { }
      (lib.mapAttrsToList
        (lversion: gversions:
          lib.mapAttrs'
            (gversion: lock:
              lib.nameValuePair
                "quilt-${escapeVersion gversion}-${escapeVersion lversion}"
                (callPackage ./server.nix { inherit lock; minecraft-server = vanillaServers."vanilla-${escapeVersion gversion}"; }))
            gversions)
        versions);
in
packages // (
  (lib.mapAttrs'
    (n: v: lib.nameValuePair "quilt-${lib.removePrefix "vanilla-" n}" v)
    (lib.genAttrs
      (builtins.filter
        (n: (lib.hasPrefix "vanilla-" n) && (builtins.hasAttr "quilt-${removeVanillaPrefix n}-${latestVersion}" packages))
        (builtins.attrNames vanillaServers))
      (gversion: builtins.getAttr "quilt-${removeVanillaPrefix gversion}-${latestVersion}" packages)))
) // {
  quilt = builtins.getAttr "quilt-${escapeVersion vanillaServers.vanilla.version}-${latestVersion}" packages;
}
