{ lib
, mkTextileLoader
, loaderVersion
, gameVersion
}:
let
  loader_lock = (lib.importJSON ./loader_locks.json).${loaderVersion};
  game_lock = (lib.importJSON ./game_locks.json).${gameVersion};
in
mkTextileLoader {
  loaderName = "quilt";
  inherit loaderVersion gameVersion;
  serverLaunch = "org.quiltmc.loader.impl.launch.server.QuiltServerLauncher";
  inherit (loader_lock) mainClass;
  libraries = loader_lock.libraries ++ game_lock.libraries;
}
