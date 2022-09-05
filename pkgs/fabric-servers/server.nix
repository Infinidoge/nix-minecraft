{ lib
, callPackage
, jre_headless
, writeShellScriptBin
, nixosTests
, our
, vanillaServers
}:
{ minecraftVersion, loaderVersion }:
let
  inherit (our.lib) escapeVersion;

  versions = lib.importJSON ./locks.json;
  minecraft-server = vanillaServers."vanilla-${escapeVersion minecraftVersion}";
  loaderLock = builtins.getAttr minecraftVersion (builtins.getAttr loaderVersion versions);

  loader = callPackage ./loader.nix { inherit loaderLock; };
in

# Taken from https://github.com/FabricMC/fabric-installer/issues/50#issuecomment-1013444858
(writeShellScriptBin "minecraft-server" ''
  echo "serverJar=${minecraft-server}/lib/minecraft/server.jar" >> fabric-server-launcher.properties
  exec ${jre_headless}/bin/java -Dlog4j.configurationFile=${./log4j.xml} $@ -jar ${loader} nogui
'').overrideAttrs (oldAttrs: rec {
  name = "fabric-${escapeVersion minecraftVersion}-${escapeVersion loaderVersion}";
  version = "${minecraftVersion}+${loaderVersion}";
  passthru = {
    tests = { inherit (nixosTests) minecraft-server; };
    updateScript = ./update.py;
  };
})
