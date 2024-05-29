{
  lib,
  fetchurl,
  stdenvNoCC,
  writeText,
  jre_headless,
  loaderName,
  loaderVersion,
  launchPrefix ? loaderName,
  gameVersion,
  serverLaunch,
  mainClass ? "",
  libraries,
  extraBuildPhase ? "",
}:

let
  lib_lock = lib.importJSON ./libraries.json;
  fetchedLibraries = lib.forEach libraries (l: "${fetchurl lib_lock.${l}}");

  classPath = lib.concatStringsSep " " fetchedLibraries;
  manifest = writeText "manifest.mf" (
    lib.our.wrapJarManifest ''
      Manifest-Version: 1.0
      Main-Class: ${serverLaunch}
      Class-Path: ${classPath}
    ''
  );
in
stdenvNoCC.mkDerivation {
  pname = "${loaderName}-server-launch";
  version = "${loaderVersion}-${gameVersion}";

  nativeBuildInputs = [ jre_headless ];

  buildPhase = ''
    ${lib.optionalString (mainClass != "") ''
      echo launch.mainClass=${mainClass} > ${launchPrefix}-server-launch.properties
    ''}

    ${extraBuildPhase}
  '';

  installPhase = ''
    rm env-vars

    jar cmvf ${manifest} $out/lib/minecraft/launch.jar .

    # Ensure Nix knows we depend on files listed in our class path.
    mkdir $out/nix-support
    echo ${classPath} > $out/nix-support/class-path
  '';

  phases = [
    "buildPhase"
    "installPhase"
  ];

  passthru = {
    inherit
      loaderName
      loaderVersion
      gameVersion
      launchPrefix
      ;

    propertyPrefix =
      {
        "fabric" = "fabric";
        "legacy-fabric" = "fabric";
        "quilt" = "loader";
      }
      .${loaderName};
  };
}
