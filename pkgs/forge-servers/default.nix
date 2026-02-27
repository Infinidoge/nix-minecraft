{
  callPackage,
  lib,
  jdk8,
  jdk17,
  jdk,
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
    ;
  versions = lib.importJSON ./lock.json;

  # Sort by attribute 'attr' using 'f' function
  sortBy = attr: f: builtins.sort (a: b: f a.${attr} b.${attr});

  stripBuild = v: builtins.head (builtins.match "(.*)-.*" v);

  getRecommendedJavaVersion =
    v:
    if versionOlder v "1.17.1" then
      jdk8
    else if versionOlder v "1.20.5" then
      jdk17
    else
      jdk;

  packages = mapAttrsToList (
    mcVersion: builds:
    sortBy "version" versionOlder (
      mapAttrsToList (
        buildNumber: value:
        callPackage ./derivation.nix {
          inherit (value) url sha256;
          version = "${mcVersion}-${buildNumber}";
          jre = getRecommendedJavaVersion mcVersion;
          minecraft-server = vanillaServers."vanilla-${escapeVersion mcVersion}";
        }
      ) builds
    )
  ) versions;

  # Latest build for each MC version
  latestBuilds = sortBy "version" versionOlder (map last packages);
in
lib.recurseIntoAttrs (
  builtins.listToAttrs (
    (map (x: nameValuePair (escapeVersion x.name) x) (flatten packages))
    ++ (map (x: nameValuePair (escapeVersion (stripBuild x.name)) x) latestBuilds)
    ++ [ (nameValuePair "forge" (last latestBuilds)) ]
  )
)
