{
  fetchModrinthModpack,
  stdenvNoCC,
}:
let
  pack = fetchModrinthModpack {
    src = ./sample-pack;
    packHash = "sha256-OAJrZEVTZx1QZe2ubrLfK/XvRusfIN8cWMbj21TYhms=";
  };
in
stdenvNoCC.mkDerivation {
  name = "modrinth-modpack-from-src-check";
  doCheck = true;
  phases = [
    "checkPhase"
    "installPhase"
  ];
  checkPhase = ''
    set -euo pipefail
    test -f '${pack}/index.json'
    test -f '${pack}/mods/lithium-fabric-0.16.2+mc1.21.5.jar'
    test -f '${pack}/config/server.properties'
  '';
  installPhase = "mkdir $out";
}
