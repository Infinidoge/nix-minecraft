{ nixosTest, outputs }:

nixosTest {
  name = "nixos-neoforge-latest";
  nodes.server =
    {
      pkgs,
      ...
    }:
    {
      imports = [ outputs.nixosModules.minecraft-servers ];

      services.minecraft-servers = {
        enable = true;
        eula = true;
        servers.neoforge = {
          enable = true;
          jvmOpts = "-Xmx512M"; # Avoid OOM
          package = pkgs.neoforge-server;
          serverProperties = {
            server-port = 25565;
            level-type = "flat"; # Make the test lighter
            max-players = 10;
          };
          managementSystem.tmux.enable = false;
          managementSystem.systemd-socket.enable = true;
        };
      };
    };

  testScript =
    { ... }:
    # python
    ''
      name = "neoforge"
      grep_logs = lambda expr: f"grep '{expr}' /srv/minecraft/{name}/logs/latest.log"

      server.wait_for_unit(f"minecraft-server-{name}.service")
      server.wait_for_open_port(25565)
      server.wait_until_succeeds(grep_logs("Done ([0-9.]\+s)! For help, type \"help\""), timeout=30)

      # Test default stopCommand/ensure graceful shutdown
      server.stop_job(f"minecraft-server-{name}.service")
      machine.wait_for_closed_port(25565)
      server.wait_until_succeeds(grep_logs("Stopping server"), timeout=30)
    '';
}
