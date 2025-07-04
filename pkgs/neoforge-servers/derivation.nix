{
  lib,
  fetchurl,
  jre_headless,
  linkFarm,
  makeWrapper,
  minecraft-server,
  runCommand,
  stdenvNoCC,
  udev,
  writeShellApplication,
  zip,

  build,
  gameVersion,
  libraryLocks,
}:
let
  inherit (lib)
    attrValues
    concatLists
    concatStringsSep
    elemAt
    map
    mapAttrs
    splitString
    ;
  specifierPath =
    specifier:
    let
      components = builtins.match "^([^:]+):([^:]+):([^@:]+).*" specifier;
      groupId = elemAt components 0;
      artifactId = elemAt components 1;
      version = elemAt components 2;
    in
    concatStringsSep "/" (
      (splitString "." groupId)
      ++ [
        artifactId
        version
      ]
    );
  mkLibrary = specifier: rec {
    name = "${specifierPath specifier}/${path.name}";
    path = fetchurl libraryLocks.${specifier};
  };
  repository = linkFarm "neoforge${build.version}-libraries" (
    (map mkLibrary build.libraries)
    ++ [
      {
        name = "net/minecraft/server/${minecraft-server.version}/server-${minecraft-server.version}.jar";
        path = minecraft-server.src;
      }
    ]
  );
  installer-unwrapped = fetchurl build.src;
  installer =
    let
      name = "neoforge-${build.version}-offline-installer";

      # Add server mappings to the jar so we can perform an offline install.
      # https://github.com/neoforged/LegacyInstaller/blob/e95a1687b24d6c1e4ba87c98ddcd42b83eeba555/src/main/java/net/minecraftforge/installer/actions/FatInstallerAction.java#L79
      # TODO: Can we just add mappings to the classpath rather than directly to the jar?
      fatJar = runCommand "${name}" { nativeBuildInputs = [ zip ]; } ''
        install -m 644 -D "${installer-unwrapped}" "$out"

        server_mappings="maven/minecraft/${minecraft-server.version}/server_mappings.txt"
        install -m 644 -D ${fetchurl gameVersion.mappings} "$server_mappings"

        zip "$out" "$server_mappings"
      '';

      wrapper = writeShellApplication {
        inherit name;
        runtimeInputs = [ jre_headless ];
        # Unfortunately, library dependencies cannot just be added to the classpath. The
        # [installer](https://github.com/neoforged/LegacyInstaller/blob/e95a1687b24d6c1e4ba87c98ddcd42b83eeba555/src/main/java/net/minecraftforge/installer/Downloader.java#L114),
        # [and NeoForge itself](https://github.com/neoforged/FancyModLoader/blob/610108bbd862a87c1266076a2592dfbc732e19c4/loader/src/main/java/net/neoforged/fml/loading/LibraryFinder.java#L28)
        # require a `libraries` directory.
        text = ''
          mkdir -p "$1/libraries"
          cp -r --no-preserve=all ${repository}/* "$1/libraries"
          java -jar ${fatJar} --offline --installServer "$1"
        '';
      };
    in
    wrapper;
in
stdenvNoCC.mkDerivation rec {
  pname = "neoforge";
  version = "${gameVersion.version}-${build.version}";
  dontUnpack = true;

  preferLocalBuild = true;

  buildInputs = [ makeWrapper ];

  buildPhase = ''
    ${lib.getExe installer} $out
    args="$out/libraries/net/neoforged/neoforge/${build.version}/unix_args.txt"
    substituteInPlace "$args" \
      --replace-fail "-DlibraryDirectory=libraries" "-DlibraryDirectory=$out/libraries" \
      --replace-fail "libraries/" "$out/libraries/"
    makeWrapper "${jre_headless}/bin/java" "$out/bin/${meta.mainProgram}" \
      ${lib.optionalString stdenvNoCC.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ udev ]}"} \
      --append-flags "@$args"
  '';

  passthru = {
    inherit repository installer installer-unwrapped;
    updateScript = ./update.py;
    gameVersion = gameVersion.version;
    loaderVersion = build.version;
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
