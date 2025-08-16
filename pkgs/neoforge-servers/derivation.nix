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
      fatJar = runCommand "${name}" { nativeBuildInputs = [ zip ]; } ''
        install -m 644 -D "${installer-unwrapped}" "$out"

        # add server mappings to the classpath so we can perform an offline install
        # see the result of --generate-fat
        server_mappings="maven/minecraft/${minecraft-server.version}/server_mappings.txt"
        install -m 644 -D ${fetchurl gameVersion.mappings} "$server_mappings"

        zip "$out" "$server_mappings"
      '';
      wrapper = writeShellApplication {
        inherit name;
        runtimeInputs = [ jre_headless ];
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
  inherit (build) version;
  dontUnpack = true;

  preferLocalBuild = false; # unlike other loaders, the install/patching process is rather CPU intensive

  buildInputs = [ makeWrapper ];

  buildPhase = ''
    ${lib.getExe installer} $out
    args="$out/libraries/net/neoforged/neoforge/${version}/unix_args.txt"
    substituteInPlace "$args" \
      --replace-fail "-DlibraryDirectory=libraries" "-DlibraryDirectory=$out/libraries" \
      --replace-fail "libraries/" "$out/libraries/"
    makeWrapper "${jre_headless}/bin/java" "$out/bin/${meta.mainProgram}" \
      --append-flags "@$args" \
      ${lib.optionalString stdenvNoCC.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ udev ]}"}
  '';

  passthru = {
    inherit repository installer installer-unwrapped;
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
