{
  lib,
  stdenvNoCC,
  jq,
  moreutils,
  curl,
  cacert,
  unzip,
  coreutils,
}:

let
  fetchModrinthModpack =
    {
      # Provide a path to the modpack source directory (containing index.json),
      # a local .mrpack archive, or a URL to a .mrpack archive.
      src ? null,
      url ? null,
      packHash ? "",
      # Either 'server', 'client' or 'both' (to get all files)
      side ? "server",
      ...
    }@args:
    let
      srcNull = src == null;
      urlNull = url == null;
      srcPath = if srcNull then "" else src;
      urlPath = if urlNull then "" else url;
      drv = fetchModrinthModpack args;
    in

    assert lib.assertMsg (
      srcNull != urlNull # equivalent of (src != null) xor (url != null)
    ) "Either 'src' or 'url' must be provided to fetchModrinthModpack";

    assert lib.assertMsg (builtins.elem side [
      "server"
      "client"
      "both"
    ]) "'side' must be one of: server, client, both";

    stdenvNoCC.mkDerivation (
      {
        pname = args.pname or "modrinth-pack";
        version = args.version or "";

        dontUnpack = true;

        buildInputs = [
          jq
          moreutils
          curl
          cacert
          unzip
          coreutils
        ];

        buildPhase = ''
          set -euo pipefail
          runHook preBuild

          mkdir -p pack-src

          if [ "${if !urlNull then "1" else "0"}" = "1" ]; then
            curl -L "${urlPath}" > modpack.mrpack
            unzip -q modpack.mrpack -d pack-src
          elif [ -d "${srcPath}" ]; then
            cp -r "${srcPath}"/. pack-src/
          else
            unzip -q "${srcPath}" -d pack-src
          fi

          test -f pack-src/index.json

          while IFS= read -r file; do
            if [ "${side}" != "both" ]; then
              envState=$(echo "$file" | jq -r --arg side "${side}" '.env[$side] // "required"')
              if [ "$envState" = "unsupported" ]; then
                continue
              fi
            fi

            path=$(echo "$file" | jq -r '.path')
            url=$(echo "$file" | jq -r '.downloads[0]')
            mkdir -p "$(dirname "$path")"
            curl -L "$url" > "$path"

            if echo "$file" | jq -e '.hashes.sha512 != null' > /dev/null; then
              expected=$(echo "$file" | jq -r '.hashes.sha512')
              actual=$(${coreutils}/bin/sha512sum "$path" | cut -d' ' -f1)
            elif echo "$file" | jq -e '.hashes.sha1 != null' > /dev/null; then
              expected=$(echo "$file" | jq -r '.hashes.sha1')
              actual=$(${coreutils}/bin/sha1sum "$path" | cut -d' ' -f1)
            else
              echo "No supported hash for '$path' (supported: sha512, sha1)" >&2
              exit 1
            fi

            if [ "$actual" != "$expected" ]; then
              echo "Hash mismatch for '$path'" >&2
              echo "expected: $expected" >&2
              echo "actual:   $actual" >&2
              exit 1
            fi
          done < <(jq -c '.files[]' pack-src/index.json)

          if [ -d pack-src/overrides ]; then
            cp -r pack-src/overrides/. .
          fi

          if [ "${side}" = "server" ] && [ -d pack-src/server-overrides ]; then
            cp -r pack-src/server-overrides/. .
          fi

          if [ "${side}" = "client" ] && [ -d pack-src/client-overrides ]; then
            cp -r pack-src/client-overrides/. .
          fi

          if [ "${side}" = "both" ]; then
            if [ -d pack-src/server-overrides ]; then
              cp -r pack-src/server-overrides/. .
            fi
            if [ -d pack-src/client-overrides ]; then
              cp -r pack-src/client-overrides/. .
            fi
          fi

          # Keep the source manifest in output for passthru consumers.
          cp pack-src/index.json ./index.json

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          # Fix non-determinism
          rm -rf env-vars
          jq -Sc '.' index.json | sponge index.json

          mkdir -p "$out"
          cp * -r "$out/"

          runHook postInstall
        '';

        passthru = {
          # Modrinth index manifest as a nix expression.
          manifest = builtins.fromJSON (builtins.readFile "${drv}/index.json");

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
fetchModrinthModpack
