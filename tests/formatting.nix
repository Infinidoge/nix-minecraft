{
  lib,
  self,
  outputs,
  system,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  name = "formatting-check";
  src = self;
  doCheck = true;
  phases = [
    "checkPhase"
    "installPhase"
  ];
  checkPhase = "${lib.getExe outputs.formatter.${system}} --ci $src";
  installPhase = ''mkdir "$out"'';
}
