{
  lib,
  callPackage,
  vanillaServers,
}:
let
  inherit (lib.our) escapeVersion;
  inherit (lib)
    nameValuePair
    flatten
    last
    versionOlder
    mapAttrsToList
    versions
    ;

  sortBy = attr: f: builtins.sort (a: b: f a.${attr} b.${attr});

  loaderLocks = lib.importJSON ./loader_locks.json;
  libraryLocks = lib.importJSON ./library_locks.json;
  gameLocks = lib.importJSON ./game_locks.json;

  packages = mapAttrsToList (
    gameVersion: builds:
    sortBy "version" versionOlder (
      mapAttrsToList (
        buildVersion: build:
        callPackage ./derivation.nix {
          inherit libraryLocks;
          build = build // {
            version = buildVersion;
          };
          gameVersion = gameLocks.${gameVersion} // {
            version = gameVersion;
          };
          minecraft-server = vanillaServers."vanilla-${escapeVersion gameVersion}";
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
