{ callPackage
, nixosTests
, writeShellScriptBin
, minecraft-server
, jre_headless
, lock
, version
}:
let
  loader = callPackage ./loader.nix { inherit lock; };
in
(writeShellScriptBin "minecraft-server" ''
  echo "serverJar=${minecraft-server}/lib/minecraft/server.jar" >> quilt-server-launcher.properties
  exec ${jre_headless}/bin/java $@ -jar ${loader} nogui
'').overrideAttrs (oldAttrs: rec {
	name = "quilt-${version}";
  inherit version;
  passthru = {
    tests = { inherit (nixosTests) minecraft-server; };
    updateScript = ./update.py;
  };
})
