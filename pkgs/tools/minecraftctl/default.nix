{
  lib,
  python313,
  socat,
  tmux,
  coreutils,
  pyright,
}:
let
  py = python313;
in
py.pkgs.buildPythonApplication {
  name = "minecraftctl";
  pyproject = true;
  src = ./.;
  nativeBuildInputs = [ py.pkgs.setuptools ];
  propagatedBuildInputs = [
    py.pkgs.httpx
    py.pkgs.typer
    py.pkgs.pydantic
  ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      socat
      tmux
      coreutils
    ])
  ];
  pythonImportsCheck = [ "minecraftctl.main" ];

  strictDeps = true;
  checkPhase = ''
    ${lib.getExe py.pkgs.black} .
    ${lib.getExe pyright} minecraftctl
  '';
}
