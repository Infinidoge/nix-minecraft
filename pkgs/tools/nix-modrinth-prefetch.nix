{
  runtimeShell,
  writeShellScriptBin,
  curl,
  jq,
  gnused,
}:
writeShellScriptBin "nix-modrinth-prefetch" ''
  input=$(${curl}/bin/curl --no-progress-meter https://api.modrinth.com/v2/version/$1)

  if [[ $input == "" ]]; then
    echo "Invalid version"
    exit 1
  fi

  echo $input \
  | ${jq}/bin/jq -c '.files | (.[] | select(.primary == true)) // .[0]  | {url: .url, sha512: .hashes.sha512}' \
  | ${gnused}/bin/sed 's/{"url":"\(.\+\)","sha512":"\(.\+\)"}/fetchurl { url = "\1"; sha512 = "\2"; }/'
''
