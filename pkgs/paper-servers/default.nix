{
  callPackage,
  lib,
  jdk8,
  jdk11,
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

  # Remove -build... suffix
  stripBuild = v: builtins.head (builtins.match "(.*)-build.*" v);
  # Sort by attribute 'attr' using 'f' function
  sortBy = attr: f: builtins.sort (a: b: f a.${attr} b.${attr});

  # https://docs.papermc.io/paper/getting-started#requirements
  getRecommendedJavaVersion =
    v:
    if versionOlder v "1.11.2" then
      jdk8
    else if versionOlder v "1.16.5" then
      jdk11
    else
      jdk;

  packages = mapAttrsToList (
    mcVersion: builds:
    sortBy "version" versionOlder (
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
  latestBuilds = sortBy "version" versionOlder (map last packages);
in
lib.recurseIntoAttrs (
  builtins.listToAttrs (
    (map (x: nameValuePair (escapeVersion x.name) x) (flatten packages))
    ++ (map (x: nameValuePair (escapeVersion (stripBuild x.name)) x) latestBuilds)
    ++ [ (nameValuePair "paper" (last latestBuilds)) ]
  )
)
