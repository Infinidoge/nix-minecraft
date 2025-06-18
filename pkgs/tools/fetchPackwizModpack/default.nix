{
  lib,
  stdenvNoCC,
  fetchurl,
  jre_headless,
  jq,
  moreutils,
  curl,
  cacert,
}:

let
  fetchPackwizModpack =
    {
      # Provide a path to the packwiz modpack source directory,
      # or a URL to a pack.toml file.
      src ? null,
      url ? null,
      packHash ? "",
      # Either 'server' or 'both' (to get client mods as well)
      side ? "server",
      # The derivation passes through a 'manifest' expression, that includes
      # useful metadata (such as MC version).
      # By default, if you access it, IFD will be used. If you want to use
      # 'manifest' without IFD, you can alternatively pass a manifestHash, that
      # allows us to fetch it with builtins.fetchurl instead.
      manifestHash ? null,
      ...
    }@args:
    let
      srcNull = src == null;
      urlNull = url == null;
      toml = builtins.fromTOML (builtins.readFile (src + "/pack.toml"));
      pname = args.pname or (if !srcNull then toml.name else "packwiz-pack");
      version = args.version or (if !srcNull then toml.version else "");
      drv = fetchPackwizModpack args;
      bootstrapUrl = if !urlNull then url else "file://${src}/pack.toml";
    in

    assert lib.assertMsg (
      srcNull != urlNull # equivalent of (src != null) xor (url != null)
    ) "Either 'src' or 'url' must be provided to fetchPackwizModpack";

    stdenvNoCC.mkDerivation (
      finalAttrs:
      {
        inherit pname version;

        packwizInstaller = fetchurl rec {
          pname = "packwiz-installer";
          version = "0.5.8";
          url = "https://github.com/packwiz/${pname}/releases/download/v${version}/${pname}.jar";
          hash = "sha256-+sFi4ODZoMQGsZ8xOGZRir3a0oQWXjmRTGlzcXO/gPc=";
        };

        packwizInstallerBootstrap = fetchurl rec {
          pname = "packwiz-installer-bootstrap";
          version = "0.0.3";
          url = "https://github.com/packwiz/${pname}/releases/download/v${version}/${pname}.jar";
          hash = "sha256-qPuyTcYEJ46X9GiOgtPZGjGLmO/AjV2/y8vKtkQ9EWw=";
        };

        dontUnpack = true;

        buildInputs = [
          jre_headless
          jq
          moreutils
          curl
          cacert
        ];

        buildPhase = ''
          set -euo pipefail
          runHook preBuild

          curl -L "${bootstrapUrl}" > pack.toml
          java -jar "$packwizInstallerBootstrap" \
            --bootstrap-main-jar "$packwizInstaller" \
            --bootstrap-no-update \
            --no-gui \
            --side "${side}" \
            "${bootstrapUrl}"

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          # Fix non-determinism
          rm env-vars -r
          jq -Sc '.' packwiz.json | sponge packwiz.json

          mkdir -p $out
          cp * -r $out/

          runHook postInstall
        '';

        passthru = {
          # Pack manifest as a nix expression
          # If manifestHash is not null, then we can do this without IFD.
          # Otherwise, fallback to IFD.
          manifest = lib.importTOML (
            if manifestHash != null then
              builtins.fetchurl {
                inherit url;
                sha256 = manifestHash;
              }
            else
              "${drv}/pack.toml"
          );

          # Adds an attribute set of files to the derivation.
          # Useful to add server-specific mods not part of the pack.
          addFiles =
            files:
            stdenvNoCC.mkDerivation {
              inherit (drv) pname version;
              src = null;
              dontUnpack = true;
              dontConfig = true;
              dontBuild = true;
              dontFixup = true;

              installPhase =
                ''
                  cp -as "${drv}" $out
                  chmod u+w -R $out
                ''
                + lib.concatLines (
                  lib.mapAttrsToList (name: file: ''
                    mkdir -p "$out/$(dirname "${name}")"
                    cp -as "${file}" "$out/${name}"
                  '') files
                );

              passthru = { inherit (drv) manifest; };
              meta = drv.meta or { };
            };
        };

        dontFixup = true;

        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = packHash;
      }
      // args
    );
in
fetchPackwizModpack
