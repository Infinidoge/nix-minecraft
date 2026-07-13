{
  lib,
  callPackage,
  vanillaServers,
}:
let
  inherit (lib.our)
    escapeVersion
    sortVersions
    ;
  inherit (lib)
    nameValuePair
    flatten
    last
    versionOlder
    mapAttrsToList
    versions
    ;

  loaderLocks = lib.importJSON ./loader_locks.json;
  libraryLocks = lib.importJSON ./library_locks.json;
  gameLocks = lib.importJSON ./game_locks.json;

  packages = mapAttrsToList (
    gameVersion: builds:
    sortVersions (
      mapAttrsToList (
        buildVersion: build:
        let
          vanilla-server = vanillaServers."vanilla-${escapeVersion gameVersion}";
        in
        callPackage ./derivation.nix {
          inherit libraryLocks;

          build = build // {
            version = buildVersion;
          };
          gameVersion = gameLocks.${gameVersion} // {
            version = gameVersion;
          };
          minecraft-server = vanilla-server;
          jre_headless = vanilla-server.java;
        }
      ) builds
    )
  ) loaderLocks;

  # without padding, versionOlder will incorrectly sort `1.21-21.1.000` before `1.21.8-21.8.000`
  sortableVersion = drv: "${versions.pad 3 drv.passthru.gameVersion}-${drv.passthru.loaderVersion}";

  # Latest build for each MC version
  latestBuilds = builtins.sort (a: b: versionOlder (sortableVersion a) (sortableVersion b)) (
    map last packages
  );
in
lib.recurseIntoAttrs (
  builtins.listToAttrs (
    (map (x: nameValuePair (escapeVersion x.name) x) (flatten packages))
    ++ (map (x: nameValuePair "${x.pname}-${escapeVersion x.passthru.gameVersion}" x) latestBuilds)
    ++ [ (nameValuePair "neoforge" (last latestBuilds)) ]
  )
)
