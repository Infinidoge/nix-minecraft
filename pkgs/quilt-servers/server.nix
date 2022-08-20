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
writeShellScriptBin "minecraft-server" ''
  echo "serverJar=${minecraft-server}/lib/minecraft/server.jar" >> quilt-server-launcher.properties
  exec ${jre_headless}/bin/java $@ -jar ${loader} nogui''
