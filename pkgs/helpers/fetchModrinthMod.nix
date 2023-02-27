{ stdenv
, fetchurl
, jq
, id
, hash
, lib
}:
let
  version = builtins.fromJSON
    (builtins.readFile
      (fetchurl {
        url = "https://api.modrinth.com/v2/version/${id}";
        sha256 = hash;
        downloadToTemp = true;
        postFetch = ''
          cat $downloadedFile \
          | jq -c '.files | (.[] | select(.primary == true)) // .[0] | {url: .url, sha512: .hashes.sha512}' > $out
        '';
        nativeBuildInputs = [ jq ];
      }));
in
lib.warn
  "`fetchModrinthMod` is deprecated; use `fetchurl` with `nix-modrinth-prefetch` instead. see the CHANGELOG.md for more information"
  (fetchurl { inherit (version) url sha512; })
