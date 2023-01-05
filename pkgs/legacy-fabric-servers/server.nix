{ callPackage
, writeTextFile
, writeShellScriptBin
, minecraft-server
, jre_headless
, lock
}:
let
  loader = callPackage ./loader.nix { inherit lock; };
in
# Taken from https://github.com/FabricMC/fabric-installer/issues/50#issuecomment-1013444858
writeShellScriptBin "minecraft-server" ''
  echo "serverJar=${minecraft-server}/lib/minecraft/server.jar" >> fabric-server-launcher.properties
  exec ${jre_headless}/bin/java -Dlog4j.configurationFile=${./log4j.xml} $@ -jar ${loader} nogui''
