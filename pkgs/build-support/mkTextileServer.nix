{
  callPackage,
  lib,
  writeShellScriptBin,
  minecraft-server,
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
}:
(writeShellScriptBin "minecraft-server" "exec ${lib.getExe jdk_package} -D${loader.propertyPrefix}.gameJarPath=${minecraft-server}/lib/minecraft/server.jar ${extraJavaArgs} $@ -jar ${loader}/lib/minecraft/launch.jar nogui ${extraMinecraftArgs}")
// rec {
  pname = "minecraft-server";
  version = "${minecraft-server.version}-${loader.loaderName}-${loader.loaderVersion}";
  name = "${pname}-${version}";

  passthru = {
    inherit loader;
    java = jdk_package;
  };
}
