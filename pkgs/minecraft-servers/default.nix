{ callPackage
, lib
, javaPackages
}:
let
  versions = lib.importJSON ./versions.json;

  getJavaVersion = v: (builtins.getAttr "openjdk${toString v}" javaPackages.compiler).headless;

  packages = lib.mapAttrs'
    (version: value: {
      name = "vanilla-${lib.our.escapeVersion version}";
      value = callPackage ./derivation.nix {
        inherit (value) version url sha1;
        jre_headless = getJavaVersion value.javaVersion;
      };
    })
    versions;
in
lib.recurseIntoAttrs (
  packages // {
    vanilla = builtins.getAttr "vanilla-${lib.our.escapeVersion (lib.our.latestVersion versions)}" packages;
  }
)
