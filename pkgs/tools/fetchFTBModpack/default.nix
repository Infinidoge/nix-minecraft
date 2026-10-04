{
  lib,
  stdenvNoCC,
  curl,
  cacert,
}:

let
  mkServerFiles =
    pack:
    let
      entries = builtins.readDir "${pack}";
      isExcluded = name: lib.hasPrefix "." name || lib.hasSuffix ".jar" name;
      fileNames = builtins.filter (name: name != "mods" && !(isExcluded name)) (
        builtins.attrNames entries
      );
    in
    {
      symlinks = lib.optionalAttrs (entries ? mods) { mods = "${pack}/mods"; };
      files = lib.genAttrs fileNames (name: "${pack}/${name}");
    };

  fetchFTBModpack =
    {
      # Full URL to the FTB server installer, copied from the pack's server-files page.
      #
      #   https://api.feed-the-beast.com/v1/modpacks/public/modpack/130/100501/server/linux
      #
      # The packId and versionId are parsed from this URL, so pasting the
      # link is enough. The pname/version are only used for the store path and are optional.
      #
      # Alternatively, provide packId and versionId directly.
      url ? null,
      packId ? null,
      versionId ? null,
      packHash ? "",
      # Number of download threads given to the FTB server installer.
      threads ? 4,
      ...
    }@args:
    let
      drv = fetchFTBModpack args;

      # The FTB API serves a per-pack, per-version installer binary.
      # Arm Linux uses "arm/linux", everything else uses "linux".
      serverOs = if stdenvNoCC.hostPlatform.isAarch64 then "arm/linux" else "linux";

      urlIds =
        if url != null then
          builtins.match "^https://api.feed-the-beast.com/v1/modpacks/public/modpack/([0-9]+)/([0-9]+)/server/.*$" url
        else
          null;

      packId' = if url != null then lib.toInt (builtins.elemAt urlIds 0) else packId;
      versionId' = if url != null then lib.toInt (builtins.elemAt urlIds 1) else versionId;

      installerName = "serverinstall_${toString packId'}_${toString versionId'}";
      installerUrl =
        if url != null then
          url
        else
          "https://api.feed-the-beast.com/v1/modpacks/public/modpack/${toString packId}/${toString versionId}/server/${serverOs}";
    in
    assert lib.assertMsg ((url != null) != (packId != null && versionId != null)) ''
      fetchFTBModpack: provide either 'url' or both 'packId' and 'versionId', not both.
    '';
    assert lib.assertMsg (url == null || urlIds != null) ''
      fetchFTBModpack: could not parse packId/versionId from url '${url}'.
      Expected a server installer URL from the FTB server-files page, e.g.
      https://api.feed-the-beast.com/v1/modpacks/public/modpack/130/100501/server/linux
    '';

    stdenvNoCC.mkDerivation (
      {
        pname = args.pname or "ftb-pack";
        version = args.version or (toString versionId');

        src = null;
        dontUnpack = true;
        dontConfigure = true;

        nativeBuildInputs = [
          curl
          cacert
        ];

        buildPhase = ''
          set -euo pipefail
          runHook preBuild

          mkdir -p "$out"

          export HOME="$TMPDIR"

          curl --fail --location --retry 5 --cacert ${cacert}/etc/ssl/certs/ca-bundle.crt \
            --output ${installerName} \
            "${installerUrl}"
          chmod +x ${installerName}

          SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt \
            ./${installerName} \
            -auto \
            -pack ${toString packId'} \
            -version ${toString versionId'} \
            -just-files \
            -dir "$out" \
            -no-colours \
            -threads ${toString threads}

          runHook postBuild
        '';

        passthru = {
          # Full FTB version manifest as a nix expression.
          # Same shape as fetchModrinthModpack's passthru.manifest.
          # modPackTargets.modLoader.version tells you the NeoForge/Fabric
          manifest = builtins.fromJSON (builtins.readFile "${drv}/.manifest.json");

          # Maps the pack layout onto the minecraft-servers `files`/`symlinks`
          # options, so configs can write `files = modpack.serverFiles.files;`.
          # `mods` stays a link. The server shoud never writes there.
          serverFiles = mkServerFiles drv;
          # Shorthand for the common case above; same set as serverFiles.files.
          files = (mkServerFiles drv).files;

          # Adds an attribute set of files to the derivation.
          # Useful to add server-specific mods not part of the pack.
          addFiles =
            files:
            let
              augmented = stdenvNoCC.mkDerivation {
                inherit (drv) pname version;
                src = null;
                dontUnpack = true;
                dontConfig = true;
                dontBuild = true;
                dontFixup = true;

                installPhase = ''
                  cp -as "${drv}" $out
                  chmod u+w -R $out
                ''
                + lib.concatLines (
                  lib.mapAttrsToList (name: file: ''
                    mkdir -p "$out/$(dirname "${name}")"
                    cp -as "${file}" "$out/${name}"
                  '') files
                );

                passthru = {
                  inherit (drv) manifest;
                  serverFiles = mkServerFiles augmented;
                  files = (mkServerFiles augmented).files;
                };
                meta = drv.meta or { };
              };
            in
            augmented;
        };

        dontFixup = true;

        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = packHash;
      }
      // args
    );
in
fetchFTBModpack
