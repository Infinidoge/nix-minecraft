{
  lib,
  stdenvNoCC,
  fetchurl,
  nixosTests,
  java_versions,
  jdk_package,
  version,
  url,
  sha1,

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
  pname = "minecraft-server";
  inherit version;

  src = fetchurl { inherit url sha1; };

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
    tests = { inherit (nixosTests) minecraft-server; };
    updateScript = ./update.py;
  };

  meta = with lib; {
    description = "Minecraft Server";
    homepage = "https://minecraft.net";
    license = licenses.unfreeRedistributable;
    platforms = platforms.unix;
    maintainers = with maintainers; [ infinidoge ];
    mainProgram = "minecraft-server";
  };
}
