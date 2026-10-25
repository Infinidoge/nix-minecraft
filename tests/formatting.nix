{
  lib,
  self,
  outputs,
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
  checkPhase = "${lib.getExe outputs.formatter.${stdenvNoCC.hostPlatform.system}} --ci $src";
  installPhase = ''mkdir "$out"'';
}
