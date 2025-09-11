{
  pkgs ? import <nixpkgs> { },
}:

let
  py = pkgs.python313;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    py.pkgs.typer
    pkgs.pdm
  ];
}
