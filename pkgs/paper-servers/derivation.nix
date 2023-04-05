{ lib, stdenvNoCC, fetchurl, nixosTests, jre, version, url, sha256 }:
stdenvNoCC.mkDerivation {
  pname = "paper";
  inherit version;

  src = fetchurl { inherit url sha256; };

  preferLocalBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib/minecraft
    cp -v $src $out/lib/minecraft/server.jar

    cat > $out/bin/minecraft-server << EOF
    #!/bin/sh
    exec ${jre}/bin/java \$@ -jar $out/lib/minecraft/server.jar nogui
    EOF

    chmod +x $out/bin/minecraft-server
  '';

  dontUnpack = true;

  passthru = {
    updateScript = ./update.py;
  };

  meta = with lib; {
    description = "A high performance spigot fork";
    homepage = "https://papermc.io";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    maintainers = with maintainers; [ misterio77 ];
    mainProgram = "minecraft-server";
  };
}
