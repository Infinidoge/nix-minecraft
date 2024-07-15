{ lib
, fetchurl
, stdenvNoCC
, unzip
, zip
, jre_headless
, loaderName
, loaderVersion
, gameVersion
, serverLaunch
, mainClass ? ""
, libraries
, extraBuildPhase ? ""
}:

let
  lib_lock = lib.importJSON ./libraries.json;
  fetchedLibraries = lib.forEach libraries (l: fetchurl lib_lock.${l});
in
stdenvNoCC.mkDerivation {
  pname = "${loaderName}-server-launch.jar";
  version = "${loaderName}-${loaderVersion}-${gameVersion}";
  nativeBuildInputs = [ unzip zip jre_headless ];

  libraries = fetchedLibraries;

  buildPhase = ''
    for i in $libraries; do
      unzip -o $i
    done

    cat > META-INF/MANIFEST.MF << EOF
    Manifest-Version: 1.0
    Main-Class: ${serverLaunch}
    Name: org/objectweb/asm/
    Implementation-Version: 9.3
    EOF

    ${
      if mainClass == "" then "" else ''
        cat > ${loaderName}-server-launch.properties << EOF
        launch.mainClass=${mainClass}
        EOF
      ''
    }

    ${extraBuildPhase}
  '';

  installPhase = ''
    jar cmvf META-INF/MANIFEST.MF "server.jar" .
    zip -d server.jar 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA'
    cp server.jar "$out"
  '';

  phases = [ "buildPhase" "installPhase" ];

  passthru = {
    inherit loaderName loaderVersion gameVersion;
    propertyPrefix = {
      "fabric" = "fabric";
      "legacy-fabric" = "fabric";
      "quilt" = "loader";
    }.${loaderName};
  };
}
