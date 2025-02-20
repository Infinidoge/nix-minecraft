{
  callPackage,
  lib,
  writeShellScriptBin,
  minecraft-server,
  jre_headless,
  loaderVersion,
  loaderDrv,
  loader ? (
    callPackage loaderDrv {
      inherit loaderVersion;
      gameVersion = minecraft-server.version;
    }
  ),
  extraJavaArgs ? "",
  extraMinecraftArgs ? "",
}:
# Taken from https://github.com/FabricMC/fabric-installer/issues/50#issuecomment-1013444858
(writeShellScriptBin "minecraft-server" ''exec ${lib.getExe jre_headless} -D${loader.propertyPrefix}.gameJarPath=${minecraft-server}/lib/minecraft/server.jar ${extraJavaArgs} $@ -jar ${loader} nogui ${extraMinecraftArgs}'')
// rec {
  pname = "minecraft-server";
  version = "${minecraft-server.version}-${loader.loaderName}-${loader.loaderVersion}";
  name = "${pname}-${version}";

  passthru = {
    inherit loader;
  };
}
