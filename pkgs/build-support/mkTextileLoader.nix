{
  lib,
  fetchurl,
  stdenvNoCC,
  writeText,
  jre_headless,
  loaderName,
  loaderVersion,
  gameVersion,
  serverLaunch,
  mainClass ? "",
  libraries,
  extraBuildPhase ? "",
}:

let
  lib_lock = lib.importJSON ./libraries.json;
  fetchedLibraries = lib.forEach libraries (l: "${fetchurl lib_lock.${l}}");

  version = "${loaderName}-${loaderVersion}-${gameVersion}";

  manifest = writeText "${version}-manifest.mf" (
    lib.our.wrapJarManifest ''
      Manifest-Version: 1.0
      Main-Class: ${serverLaunch}
      Class-Path: ${lib.concatStringsSep " " fetchedLibraries}
    ''
  );

  launchProperties = writeText "${loaderName}-server-launch.properties" ''
    launch.mainClass=${mainClass}
  '';
in
stdenvNoCC.mkDerivation {
  pname = "${loaderName}-server-launch.jar";
  inherit version;
  name = "${version}-server-launch.jar";

  nativeBuildInputs = [ jre_headless ];

  buildPhase = ''
    ${lib.optionalString (mainClass != "") "cp ${launchProperties} ."}

    ${extraBuildPhase}
  '';

  installPhase = ''
    rm env-vars
    jar cmvf ${manifest} "server.jar" .
    cp server.jar "$out"
  '';

  phases = [
    "buildPhase"
    "installPhase"
  ];

  passthru = {
    inherit loaderName loaderVersion gameVersion;
    propertyPrefix =
      {
        "fabric" = "fabric";
        "legacy-fabric" = "fabric";
        "quilt" = "loader";
      }
      .${loaderName};
  };
}
