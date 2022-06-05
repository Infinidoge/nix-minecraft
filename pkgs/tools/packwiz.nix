{ lib
, buildGo118Module
, fetchFromGitHub
, inputs
}:
buildGo118Module rec {
  pname = "packwiz";
  version = "unstable-2022-06-05";
  src = inputs.packwiz;
  vendorSha256 = "sha256-M9u7N4IrL0B4pPRQwQG5TlMaGT++w3ZKHZ0RdxEHPKk=";

  meta = with lib; {
    license = licenses.mit;
    maintainers = with maintainers; [ infinidoge ];
  };
}
