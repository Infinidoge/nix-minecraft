{ nixosTest, outputs }:

nixosTest {
  name = "simple";
  nodes.server = { config, pkgs, lib, ...}: {
    nixpkgs = {
      overlays = [ outputs.overlays.default ];
      config.allowUnfree = true;
    };
    imports = [ outputs.nixosModules.minecraft-servers ];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      servers.vanilla = {
        enable = true;
        jvmOpts = "-Xmx512M"; # Avoid OOM
        package = pkgs.vanilla-server;
        serverProperties = {
          server-port = 25565;
          level-type = "flat"; # Make the test lighter
          max-players = 10;
        };
      };
    };
  };

  testScript = { nodes, ... }: ''
    name = "vanilla"
    grep_logs = lambda expr: f"grep '{expr}' /srv/minecraft/{name}/logs/latest.log"
    server_cmd = lambda cmd: f"echo '{cmd}' > /run/minecraft-server/{name}.stdin"

    server.wait_for_unit(f"minecraft-server-{name}.service")
    server.wait_for_open_port(25565)
    server.wait_until_succeeds(grep_logs("Done ([0-9.]\+s)! For help, type \"help\""), timeout=30)

    server.succeed(server_cmd("list"))
    server.wait_until_succeeds(grep_logs("There are 0 of a max of 10 players online"), timeout=3)
  '';
}
