{
  callPackage,
  lib,
  jdk8,
  jdk11,
  jdk17,
  jdk21,
  jdk25,
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
    versionOlder
    mapAttrsToList
    ;

  old_versions = lib.importJSON ./old_lock.json; # 1.7.10, 1.8.8, 1.9.4
  current_versions = lib.importJSON ./lock.json;
  versions = old_versions // current_versions;

  # https://docs.papermc.io/paper/getting-started#requirements
  getRecommendedJavaVersion =
    v:
    if versionOlder v "1.11.2" then
      jdk8
    else if versionOlder v "1.16.5" then
      jdk11
    else if versionOlder v "1.20" then
      jdk17
    else if versionOlder v "26.1" then
      jdk21
    else
      jdk25;

  packages = mapAttrsToList (
    mcVersion: builds:
    sortVersions (
      mapAttrsToList (
        buildNumber: value:
        callPackage ./derivation.nix {
          inherit (value) url sha256;
          version = "${mcVersion}-build.${buildNumber}";
          jre = getRecommendedJavaVersion mcVersion;
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
