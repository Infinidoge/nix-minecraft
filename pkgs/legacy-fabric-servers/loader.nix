{ lib
, fetchurl
, stdenvNoCC
, unzip
, zip
, jre_headless
, lock
}:
let
  lib_lock = lib.importJSON ./libraries.json;
  libraries = lib.forEach lock.libraries (l: fetchurl lib_lock.${l});
in
stdenvNoCC.mkDerivation {
  name = "fabric-server-launch.jar";
  nativeBuildInputs = [ unzip zip jre_headless ];

  libraries = libraries;

  buildPhase = ''
    for i in $libraries; do
      unzip -o $i
    done

    cat > META-INF/MANIFEST.MF << EOF
    Manifest-Version: 1.0
    Main-Class: net.fabricmc.loader.impl.launch.server.FabricServerLauncher
    Name: org/objectweb/asm/
    Implementation-Version: 9.2
    EOF

    cat > fabric-server-launch.properties << EOF
    launch.mainClass=${lock.mainClass}
    EOF
  '';

  installPhase = ''
    jar cmvf META-INF/MANIFEST.MF "server.jar" .
    zip -d server.jar 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA'
    cp server.jar "$out"
  '';

  phases = [ "buildPhase" "installPhase" ];
}
