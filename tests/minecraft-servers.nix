{ flake ? builtins.getFlake (toString ../.)
, pkgs ? flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem}
, makeTest ? pkgs.callPackage (flake.inputs.nixpkgs + "/nixos/tests/make-test-python.nix")
, nixosModule ? flake.nixosModules.minecraft-servers
, minecraft-package ? flake.packages.${builtins.currentSystem}.fabric
, symlinks ? { }
}:
let
  makeTest' = test: makeTest test {
    inherit pkgs;
    inherit (pkgs) system;
  };

  seed = "2151901553968352745";
  rcon-pass = "foobar";
  rcon-port = 43000;
in
{
  minecraft-server-test = makeTest' {
    name = pkgs.lib.getName minecraft-package;
    nodes.server = { ... }: {
      environment.systemPackages = [ pkgs.mcrcon ];

      nixpkgs.config.allowUnfree = true;
      imports = [ nixosModule ];

      services.minecraft-servers = {
        enable = true;
        eula = true;
        servers.test = {
          enable = true;
          package = minecraft-package;
          symlinks = symlinks;
          serverProperties = {
            enable-rcon = true;
            level-seed = seed;
            level-type = "flat";
            generate-structures = false;
            online-mode = false;
            "rcon.password" = rcon-pass;
            "rcon.port" = rcon-port;
          };
        };
      };

      virtualisation.memorySize = 2047;
    };

    testScript = ''
      start_all()
      server.wait_for_unit("minecraft-server-test")
      server.wait_for_open_port(${toString rcon-port})
      assert "${seed}" in server.succeed(
        "mcrcon -H localhost -P ${toString rcon-port} -p '${rcon-pass}' -c 'seed'"
      )
      server.succeed("systemctl stop minecraft-server-test")
    '';
  };
}
