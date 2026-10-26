{
  callPackage,
  lib,
  writeShellScriptBin,
  minecraft-server,
  java_versions,
  jdk_package ? minecraft-server.java,
  loaderVersion,
  loaderDrv,
  loader ? (
    callPackage loaderDrv {
      inherit loaderVersion jdk_package;
      gameVersion = minecraft-server.version;
    }
  ),
  extraJavaArgs ? "",
  extraMinecraftArgs ? "",

  jre,
  jre_headless,
}:
let
  jdk_package' =
    if jre != null then
      lib.warn "use jdk_package to override the jdk of nix-minecraft packages" jre
    else if jre_headless != null then
      lib.warn "use jdk_package to override the jdk of nix-minecraft packages" jre_headless
    else
      jdk_package;
in
let
  jdk_package = jdk_package';
in

(writeShellScriptBin "minecraft-server" "exec ${lib.getExe jdk_package} -D${loader.propertyPrefix}.gameJarPath=${minecraft-server}/lib/minecraft/server.jar ${extraJavaArgs} $@ -jar ${loader}/lib/minecraft/launch.jar nogui ${extraMinecraftArgs}")
// rec {
  pname = "minecraft-server";
  version = "${minecraft-server.version}-${loader.loaderName}-${loader.loaderVersion}";
  name = "${pname}-${version}";

  passthru = {
    inherit loader;
    java = jdk_package;
    recommendedJVMArgs = java_versions.recommendedJVMArgs jdk_package;
  };
}
