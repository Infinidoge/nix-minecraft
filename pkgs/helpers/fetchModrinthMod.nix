{ stdenv
, fetchurl
, jq
, id
, hash
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
          | jq '.files | (.[] | select(.primary == true)) // .[0] | {url: .url, sha512: .hashes.sha512}' > $out
        '';
        nativeBuildInputs = [ jq ];
      }));
in
fetchurl { inherit (version) url sha512; }
