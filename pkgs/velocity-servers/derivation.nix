{
  lib,
  stdenvNoCC,
  fetchurl,
  nixosTests,
  jre_headless,
  version,
  url,
  sha256,
  channel ? "default",
}:
stdenvNoCC.mkDerivation {
  pname = "velocity";
  inherit version;

  src = fetchurl { inherit url sha256; };

  preferLocalBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib/minecraft
    cp -v $src $out/lib/minecraft/server.jar
    cat > $out/bin/velocity << EOF
    #!/bin/sh
    exec ${jre_headless}/bin/java \$@ -jar $out/lib/minecraft/server.jar nogui
    EOF
    chmod +x $out/bin/velocity
  '';

  dontUnpack = true;

  passthru = {
    tests = { inherit (nixosTests) minecraft-server; };
    updateScript = ./update.py;
    nix-minecraft = {
      type = "velocity";
      mcVersion = null;
      loaderVersion = version;
    };
  };

  meta = with lib; {
    description = "A modern, next-generation Minecraft server proxy";
    homepage = "https://papermc.io";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    maintainers = with maintainers; [ misterio77 ];
    branch = channel;
    mainProgram = "velocity";
  };
}
