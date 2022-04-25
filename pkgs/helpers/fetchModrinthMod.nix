{ stdenv
, fetchurl
, jq
, id
, hash
, fetchPrimary ? true
}:
let
  version = builtins.fromJSON
    (builtins.readFile
      (fetchurl {
        url = "https://api.modrinth.com/v2/version/${id}";
        sha256 = hash;
        downloadToTemp = true;
        postFetch = ''
          cat $downloadedFile | jq '.files | ${if fetchPrimary then ".[] | select(.primary == true)" else ".[0]"}' > $out
        '';
        nativeBuildInputs = [ jq ];
      }));
in
fetchurl {
  url = version.url;
  sha512 = version.hashes.sha512;
}
