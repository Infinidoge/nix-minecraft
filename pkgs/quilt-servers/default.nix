{ lib
, mkTextileServer
, vanillaServers
}:

let
  game_locks = lib.importJSON ./game_locks.json;
  loader_locks = lib.importJSON ./loader_locks.json;

  inherit (lib.our) escapeVersion latestVersion removeVanilla;

  latestLoaderVersion = latestVersion loader_locks;

  mkServer = gameVersion: (mkTextileServer {
    loaderVersion = latestLoaderVersion;
    loaderDrv = ./loader.nix;
    minecraft-server = vanillaServers."vanilla-${escapeVersion gameVersion}";
  });

  gameVersions = lib.attrNames game_locks;

  packagesRaw = lib.genAttrs gameVersions mkServer;
  packages = lib.mapAttrs' (version: drv: lib.nameValuePair "quilt-${escapeVersion version}" drv) packagesRaw;

  mkDeprecatedPackages = (loaderVersion: lib.mapAttrs'
    (name: drv: {
      name = "${name}-${escapeVersion loaderVersion}";
      value = lib.warn
        "`${name}-${escapeVersion loaderVersion}` is deprecated! Use `${name}.override { loaderVersion = \"${loaderVersion}\"; }` instead."
        drv;
    })
    packages);

  deprecatedPackages = lib.attrsets.mergeAttrsList (builtins.map mkDeprecatedPackages (lib.attrNames loader_locks));
in
lib.recurseIntoAttrs (
  packages
  // {
    quilt = builtins.getAttr "quilt-${escapeVersion vanillaServers.vanilla.version}" packages;
  } // deprecatedPackages
)
