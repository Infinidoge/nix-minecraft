{
  callPackage,
  lib,
  jre8,
  jre_headless,
}:
let
  versions = lib.importJSON ./versions.json;

  # Older Minecraft versions that were written for Java 8, required Java 8.
  # Mojang has since rewritten a lot of their codebase so that Java versions
  # are no longer as important for stability as they used to be. Meaning we can
  # target latest the latest JDK for all newer versions of Minecraft.
  # TODO: Assert that jre_headless >= java version
  getJavaVersion = v: if v == 8 then jre8 else jre_headless;

  packages = lib.mapAttrs' (version: value: {
    name = "vanilla-${lib.our.escapeVersion version}";
    value = callPackage ./derivation.nix {
      inherit (value) version url sha1;
      jre_headless = getJavaVersion value.javaVersion;
    };
  }) versions;
in
lib.recurseIntoAttrs (
  packages
  // {
    vanilla = builtins.getAttr "vanilla-${lib.our.escapeVersion (lib.our.latestVersion versions)}" packages;
  }
)
