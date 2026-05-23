{
  callPackage,
  lib,
  java_versions,
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
    mapAttrsToList
    ;

  versions = lib.importJSON ./lock.json;

  getLog4j =
    v:
    if lib.versionOlder v "1.17" then
      "-Dlog4j.configurationFile=" + ./purpur_log4j2_1141-1165.xml
    else if lib.versionOlder v "1.18.2" then
      "-Dlog4j.configurationFile=" + ./purpur_log4j2_117.xml
    else
      ""; # newer than 1.18.1 are patched.

  packages = mapAttrsToList (
    mcVersion: builds:
    sortVersions (
      mapAttrsToList (
        buildNumber: value:
        callPackage ./derivation.nix rec {
          inherit (value) sha256;
          version = "${mcVersion}";
          url = "https://api.purpurmc.org/v2/purpur/${mcVersion}/${buildNumber}/download";
          jre = java_versions.getPaperRecommended mcVersion;
          log4j = getLog4j mcVersion;
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
    ++ (map (x: nameValuePair (escapeVersion x.name) x) latestBuilds)
    ++ [ (nameValuePair "purpur" (last latestBuilds)) ]
  )
)
