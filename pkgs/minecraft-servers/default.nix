{ callPackage
, lib
, our
, javaPackages
}:
let
  versions = lib.importJSON ./versions.json;

  getJavaVersion = v: (builtins.getAttr "openjdk${toString v}" javaPackages.compiler).headless;

  packages = lib.mapAttrs'
    (version: value: {
      name = "vanilla-${our.lib.escapeVersion version}";
      value = callPackage ./derivation.nix {
        inherit (value) version url sha1;
        jre_headless = getJavaVersion value.javaVersion;
      };
    })
    versions;
in
packages // {
  vanilla = builtins.getAttr "vanilla-${our.lib.escapeVersion (our.lib.latestVersion versions)}" packages;
}
