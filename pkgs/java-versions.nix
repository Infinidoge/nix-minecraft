{
  lib,
  jdk8,
  jdk11,
  jdk17,
  jdk21,
  jdk25,
}:
let
  inherit (lib)
    versionOlder
    ;

  getMajorVersion = jdk: lib.toInt (lib.head (lib.splitString "." jdk.version));
in
rec {
  inherit
    jdk8
    jdk11
    jdk17
    jdk21
    jdk25
    ;

  latest = jdk25;

  # Older Minecraft versions that were written for Java 8, required Java 8.
  # Mojang has since rewritten a lot of their codebase so that Java versions
  # are no longer as important for stability as they used to be. Meaning we can
  # target the latest JDK for all newer versions of Minecraft.
  # TODO: Assert that jre_headless >= java version
  getLatest =
    javaVersion:
    if javaVersion == 8 then
      jdk8
    else
      lib.warnIf (javaVersion > getMajorVersion latest) "Requires newer Java than current latest" latest;

  getEarliest =
    javaVersion:
    if javaVersion == 8 then
      jdk8
    else if javaVersion == 16 then # coerce to Java 17
      jdk17
    else if javaVersion == 17 then
      jdk17
    else if javaVersion == 21 then
      jdk21
    else if javaVersion == 25 then
      jdk25
    else
      lib.warn "Improper Java version ${toString javaVersion}, defaulting to latest" latest;

  # https://docs.papermc.io/paper/getting-started#requirements
  getPaperRecommended =
    minecraftVersion:
    if versionOlder minecraftVersion "1.11.2" then
      jdk8
    else if versionOlder minecraftVersion "1.16.5" then
      jdk11
    else if versionOlder minecraftVersion "1.20" then
      jdk17
    else if versionOlder minecraftVersion "26.1" then
      jdk21
    else
      jdk25;
}
