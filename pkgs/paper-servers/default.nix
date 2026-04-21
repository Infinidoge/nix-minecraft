{
  callPackage,
  lib,
  java_versions,
  vanillaServers,
}:
let
  inherit (lib.our)
    escapeVersion
    stripBuild
    sortVersions
    ;
  inherit (lib)
    nameValuePair
    flatten
    last
    mapAttrsToList
    ;

  old_versions = lib.importJSON ./old_lock.json; # 1.7.10, 1.8.8, 1.9.4
  current_versions = lib.importJSON ./lock.json;
  versions = old_versions // current_versions;

  packages = mapAttrsToList (
    mcVersion: builds:
    sortVersions (
      mapAttrsToList (
        buildNumber: value:
        callPackage ./derivation.nix {
          inherit (value) url sha256;
          version = "${mcVersion}-build.${buildNumber}";
          jre = java_versions.getPaperRecommended mcVersion;
          minecraft-server = vanillaServers."vanilla-${escapeVersion mcVersion}";
        }
      ) builds
    )
  ) versions;

  # Latest build for each MC version
  latestBuilds = sortVersions (map last packages);
in
lib.recurseIntoAttrs (
  builtins.listToAttrs (
    (map (x: nameValuePair (escapeVersion x.name) x) (flatten packages))
    ++ (map (x: nameValuePair (escapeVersion (stripBuild x.name)) x) latestBuilds)
    ++ [ (nameValuePair "paper" (last latestBuilds)) ]
  )
)
