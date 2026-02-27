{
  lib,
  stdenvNoCC,
  writeShellApplication,
  fetchurl,
  nixosTests,
  jre,
  version,
  url,
  sha256,
  minecraft-server,
}:
stdenvNoCC.mkDerivation rec {
  pname = "forge";
  inherit version;

  src = fetchurl { inherit url sha256; };

  preferLocalBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib/minecraft
    cp -v $src $out/lib/minecraft/installer.jar

    cat > $out/bin/minecraft-server << EOF
    #!/bin/sh
    if [ -e "forge-${version}*.jar" ] || [ -e "forge-${version}.jar" ]; then
      echo "Running Forge..."
    else
      echo "Installing Forge..."
      ${lib.getExe jre} -jar $out/lib/minecraft/installer.jar --installServer
    fi

    exec ${lib.getExe jre} \$@ -jar forge-${version}*.jar nogui
    EOF

    chmod +x $out/bin/minecraft-server
  '';

  dontUnpack = true;

  passthru = {
    updateScript = ./update.py;
    # If you plan on running paper without internet, be sure to link this jar
    # to `cache/mojang_{version}.jar`.
    vanillaJar = "${minecraft-server}/lib/minecraft/server.jar";
  };

  meta = with lib; {
    description = "Massive API and mod loader used by modders to hook into Minecraft's code.";
    homepage = "https://minecraftforge.net";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    maintainers = with maintainers; [ hustlerone ];
    mainProgram = "minecraft-server";
  };
}
