{
  lib,
  stdenvNoCC,
  fetchurl,
  nixosTests,
  java_versions,
  jdk_package,
  version,
  url,
  sha256,
  minecraft-server,

  jre,
  jre_headless,
}:
let
  jdk_package' =
    if jre != null then
      lib.warn "use jdk_package to override the jdk of nix-minecraft packages" jre
    else if jre_headless != null then
      lib.warn "use jdk_package to override the jdk of nix-minecraft packages" jre_headless
    else
      jdk_package;
in
let
  jdk_package = jdk_package';
in

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
    exec ${jdk_package}/bin/java \$@ -jar $out/lib/minecraft/server.jar nogui
    EOF

    chmod +x $out/bin/minecraft-server
  '';

  dontUnpack = true;

  passthru = {
    java = jdk_package;
    recommendedJVMArgs = java_versions.recommendedJVMArgs jdk_package;
    updateScript = ./update.py;
    # If you plan on running paper without internet, be sure to link this jar
    # to `cache/mojang_{version}.jar`.
    vanillaJar = "${minecraft-server}/lib/minecraft/server.jar";
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
