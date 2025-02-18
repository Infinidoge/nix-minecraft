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

  classPath = lib.concatStringsSep " " fetchedLibraries;
  manifest = writeText "${version}-manifest.mf" (
    lib.our.wrapJarManifest ''
      Manifest-Version: 1.0
      Main-Class: ${serverLaunch}
      Class-Path: ${classPath}
    ''
  );
in
stdenvNoCC.mkDerivation {
  pname = "${loaderName}-server-launch";
  inherit version;

  nativeBuildInputs = [ jre_headless ];

  buildPhase = ''
    ${lib.optionalString (mainClass != "") ''
      echo launch.mainClass=${mainClass} > ${loaderName}-server-launch.properties
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
