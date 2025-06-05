{ nixosTest, outputs }:

nixosTest {
  name = "nixos-simple";
  nodes.server =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
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

  testScript =
    { nodes, ... }:
    ''
      name = "vanilla"
      grep_logs = lambda expr: f"grep '{expr}' /srv/minecraft/{name}/logs/latest.log"

      server.wait_for_unit(f"minecraft-server-{name}.service")
      server.wait_for_open_port(25565)
      server.wait_until_succeeds(grep_logs("Done ([0-9.]\+s)! For help, type \"help\""), timeout=30)
    '';
}
