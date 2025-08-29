{
  writeShellApplication,
  lib,

  jq,
  jc,
  socat,
  tmux,
  curl,
  unixtools,
}:
writeShellApplication {
  name = "minecraftctl";
  runtimeInputs = [
    jq
    jc
    socat
    tmux
    unixtools.column
    curl
  ];
  text = lib.fileContents ./minecraftctl.sh;
}
