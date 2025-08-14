{
  callPackage,
  lib,
  jdk11,
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

  # Remove -build... suffix
  stripBuild = v: builtins.head (builtins.match "(.*)-build.*" v);
  # Sort by attribute 'attr' using 'f' function
  sortBy = attr: f: builtins.sort (a: b: f a.${attr} b.${attr});

  # https://docs.papermc.io/paper/getting-started#requirements
  getRecommendedJavaVersion =
    v:
    # oldest version is 1.14.1
    # Version older than 1.1 1.1 = false
    if versionOlder v "1.17" then
      jdk11
    else if versionOlder v "1.18.2" then # paper says 1.18.1+ but 1.18.1 max is 17
      jdk17
    else
      jdk;

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
    sortBy "version" versionOlder (
      mapAttrsToList (
        buildNumber: value:
        callPackage ./derivation.nix rec {
          inherit (value) sha256;
          version = "${mcVersion}-build.${buildNumber}";
          url = "https://api.purpurmc.org/v2/purpur/${version}/${buildNumber}/download";
          jre = getRecommendedJavaVersion mcVersion;
          log4j = getLog4j mcVersion;
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
    ++ [ (nameValuePair "purpur" (last latestBuilds)) ]
  )
)
