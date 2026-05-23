{
  callPackage,
  lib,
  java_versions,
}:
let
  versions = lib.importJSON ./versions.json;

  packages = lib.mapAttrs' (version: value: {
    name = "vanilla-${lib.our.escapeVersion version}";
    value = callPackage ./derivation.nix {
      inherit (value) version url sha1;
      jre_headless = java_versions.getLatest value.javaVersion;
    };
  }) versions;
in
lib.recurseIntoAttrs (
  packages
  // {
    vanilla = builtins.getAttr "vanilla-${lib.our.escapeVersion (lib.our.latestVersion versions)}" packages;
  }
)
