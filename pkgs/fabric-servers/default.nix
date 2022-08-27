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
                "fabric-${escapeVersion gversion}-${escapeVersion lversion}"
                (callPackage ./server.nix { inherit lock; minecraft-server = vanillaServers."vanilla-${escapeVersion gversion}"; }))
            gversions)
        versions);
in
packages // (
	(lib.mapAttrs'
		(n: v: lib.nameValuePair "fabric-${lib.removePrefix "vanilla-" n}" v)
		(lib.genAttrs
			(builtins.filter
				(n: (lib.hasPrefix "vanilla-" n) && (builtins.hasAttr "fabric-${removeVanillaPrefix n}-${latestVersion}" packages))
				(builtins.attrNames vanillaServers))
			(gversion: builtins.getAttr "fabric-${removeVanillaPrefix gversion}-${latestVersion}" packages)))
) // {
	fabric = builtins.getAttr "fabric-${escapeVersion vanillaServers.vanilla.version}-${latestVersion}" packages;
}
