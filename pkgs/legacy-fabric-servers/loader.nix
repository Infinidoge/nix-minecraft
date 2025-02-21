{
  lib,
  mkTextileLoader,
  loaderVersion,
  gameVersion,
}:
let
  loader_lock = (lib.importJSON ./loader_locks.json).${loaderVersion};
  game_lock = (lib.importJSON ./game_locks.json).${gameVersion};
in
mkTextileLoader {
  loaderName = "legacy-fabric";
  launchPrefix = "fabric";
  inherit loaderVersion gameVersion;
  serverLaunch = "net.fabricmc.loader.impl.launch.server.FabricServerLauncher";
  inherit (loader_lock) mainClass;
  libraries = loader_lock.libraries ++ game_lock.libraries;
}
