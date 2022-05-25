{ runtimeShell, writeShellScriptBin, curl, jq, coreutils, gawk }:
writeShellScriptBin "nix-prefetch-modrinth" ''
  input=$(${curl}/bin/curl --no-progress-meter https://api.modrinth.com/v2/version/$1)

  if [[ $input == "" ]]; then
    echo "Invalid version"
    exit 1
  fi

  echo $input \
  | ${jq}/bin/jq -c '.files | (.[] | select(.primary == true)) // .[0]  | {url: .url, sha512: .hashes.sha512}' \
  | ${coreutils}/bin/sha256sum \
  | ${gawk}/bin/awk '{print $1}'
''
