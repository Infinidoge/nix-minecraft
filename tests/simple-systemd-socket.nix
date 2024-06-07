{ nixosTest, outputs }:

nixosTest {
  name = "simple-systemd-socket";
  nodes.server = { config, pkgs, lib, ... }: {
    imports = [ outputs.nixosModules.minecraft-servers ];

    services.minecraft-servers = {
      enable = true;
      eula = true;

      managementSystem.tmux.enable = false;

      servers.vanilla = {
        managementSystem.systemd-socket = {
          enable = true;
          stdinSocket.path = server: "/run/minecraft/my_unusual_socket_path.sock";
        };

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
    server_cmd = lambda cmd: f"echo '{cmd}' > /run/minecraft/my_unusual_socket_path.sock"

    server.wait_for_unit(f"minecraft-server-{name}.service")
    server.wait_for_open_port(25565)
    server.wait_until_succeeds(grep_logs("Done ([0-9.]\+s)! For help, type \"help\""), timeout=30)

    server.succeed(server_cmd("list"))
    server.wait_until_succeeds(grep_logs("There are 0 of a max of 10 players online"), timeout=3)

    # Trigger unknown-command message, check it works
    server.succeed(server_cmd("foobar"))
    server.wait_until_succeeds(grep_logs("Unknown or incomplete command"), timeout=3)
  '';
}
