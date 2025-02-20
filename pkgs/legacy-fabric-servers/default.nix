{
  lib,
  mkTextileServer,
  vanillaServers,
}:

let
  game_locks = lib.importJSON ./game_locks.json;
  loader_locks = lib.importJSON ./loader_locks.json;

  inherit (lib.our) escapeVersion latestVersion removeVanilla;

  latestLoaderVersion = latestVersion loader_locks;

  mkServer =
    gameVersion:
    (mkTextileServer {
      loaderVersion = latestLoaderVersion;
      loaderDrv = ./loader.nix;
      minecraft-server = vanillaServers."vanilla-${escapeVersion gameVersion}";
      extraJavaArgs = "-Dlog4j.configurationFile=${./log4j.xml}";
    });

  gameVersions = lib.attrNames game_locks;

  packagesRaw = lib.genAttrs gameVersions mkServer;
  packages = lib.mapAttrs' (
    version: drv: lib.nameValuePair "legacy-fabric-${escapeVersion version}" drv
  ) packagesRaw;
in
lib.recurseIntoAttrs packages
