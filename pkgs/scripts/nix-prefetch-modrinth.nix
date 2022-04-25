{ runtimeShell, writeShellScriptBin, curl, jq, coreutils, gawk }:
writeShellScriptBin "nix-prefetch-modrinth" ''
  ${curl}/bin/curl --no-progress-meter https://api.modrinth.com/v2/version/$1 \
  | ${jq}/bin/jq '.files | .[] | select(.primary == true)' \
  | ${coreutils}/bin/sha256sum \
  | ${gawk}/bin/awk '{print $1}'
''
