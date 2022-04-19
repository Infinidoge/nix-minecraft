{ stdenv
, fetchurl
, id
, responseHash
}:
let
  version = builtins.fromJSON
    (builtins.readFile
      (fetchurl {
        url = "https://api.modrinth.com/v2/version/${id}";
        sha256 = responseHash;
      }));
  file = (builtins.elemAt version.files 0);
in
fetchurl {
  url = file.url;
  sha512 = file.hashes.sha512;
  # Since Modrinth is kind enough to give the hash, we can grab it from the API result
  # And pre-fetch the API response instead of the file.
  #
  # $ nix-prefetch-url https://api.modrinth.com/v2/version/$version-id
}
