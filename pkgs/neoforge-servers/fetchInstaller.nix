{
  pkgs ? import <nixpkgs> { },
  srcJson,
}:
let
  inherit (builtins.fromJSON srcJson) name url hash;
in
pkgs.runCommandNoCCLocal "${name}" { nativeBuildInputs = [ pkgs.unzip ]; } ''
  mkdir $out
  unzip -j ${pkgs.fetchurl { inherit name url hash; }} install_profile.json version.json -d $out
''
