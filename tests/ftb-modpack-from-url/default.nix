{
  fetchFTBModpack,
  stdenvNoCC,
}:
let
  pack = fetchFTBModpack {
    # StoneBlock 4, 1.21.0 release
    url = "https://api.feed-the-beast.com/v1/modpacks/public/modpack/130/100501/server/linux";
    # FOD hash: if the output changes without a hash bump, the build fails.
    packHash = "sha256-jx2rrXZQPGAQss5crJ3rBD2eC1znV2Z0trD5CXsdDz8=";
  };
in
stdenvNoCC.mkDerivation {
  name = "ftb-modpack-from-url-check";
  doCheck = true;
  phases = [
    "checkPhase"
    "installPhase"
  ];
  checkPhase = ''
    set -euo pipefail
    test -f '${pack}/.manifest.json'
    test -d '${pack}/mods'
    test -d '${pack}/config'
    test -d '${pack}/defaultconfigs'
    test -d '${pack}/kubejs'
    test -d '${pack}/datapacks'
    test -d '${pack}/resourcepacks'
    test -d '${pack}/ftbteambases'
    test -d '${pack}/schematics'
    test -d '${pack}/configureddefaults'
    test -f '${pack}/mods/aaron-1.21.1-1.20.0-build.28.jar'
  '';
  installPhase = "mkdir $out";
}
