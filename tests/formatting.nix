{ lib, self, outputs, system, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  name = "formatting-check";
  src = self;
  doCheck = true;
  phases = [ "checkPhase" "installPhase" ];
  checkPhase = "${lib.getExe outputs.formatter.${system}} --check $src";
  installPhase = ''mkdir "$out"'';
}
