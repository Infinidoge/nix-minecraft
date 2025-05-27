{
  fetchPackwizModpack,
  stdenvNoCC,
}:
let
  pack = fetchPackwizModpack {
    src = ./sample-pack;
    packHash = "sha256-x7e1UzyVKfprQgayVLUcN4nzcPUx9nq+D/NmLe+ElKs=";
  };
in
stdenvNoCC.mkDerivation {
  name = "packwiz-from-src-check";
  doCheck = true;
  phases = [
    "checkPhase"
    "installPhase"
  ];
  checkPhase = ''
    set -euo pipefail
    test -f ${pack}/pack.toml
    test -f '${pack}/mods/lithium-fabric-0.16.2+mc1.21.5.jar'
  '';
  installPhase = "mkdir $out";
}
