{ nixosTest, outputs }:

nixosTest {
  name = "files-symlinks";
  nodes.server = { config, pkgs, lib, ... }: {
    imports = [ outputs.nixosModules.minecraft-servers ];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      servers.paper = {
        enable = true;
        managementSystem = { tmux.enable = false; systemd-socket.enable = true; };
        jvmOpts = "-Xmx512M"; # Avoid OOM
        package = pkgs.paperServers.paper-1_19_4;
        serverProperties = {
          server-port = 25565;
          level-type = "flat"; # Make the test lighter
          online-mode = false;
        };
        symlinks = {
          # To avoid internet access
          "cache/mojang_1.19.4.jar" = "${pkgs.vanillaServers.vanilla-1_19_4}/lib/minecraft/server.jar";
        };
        files = {
          # A mutable file
          "ops.json".value = [{
            name = "Misterio7x";
            # Offline mode UUID that is derived from the username
            # Does not need internet to resolve, and never changes.
            uuid = "b094c46b-90d6-385a-96d9-5e740ed98070";
            level = 4;
          }];
          "spigot.yml".value = {
            messages.unknown-command = "Unknown command, dummy!";
          };
        };
      };
    };
  };

  testScript = { nodes, ... }: ''
    name = "paper"
    grep_logs = lambda expr: f"grep '{expr}' /srv/minecraft/{name}/logs/latest.log"
    server_cmd = lambda cmd: f"echo '{cmd}' > /run/minecraft/paper.stdin"

    server.wait_for_unit(f"minecraft-server-{name}.service")
    server.wait_for_open_port(25565)
    server.wait_until_succeeds(grep_logs("Done ([0-9.]\+s)! For help, type \"help\""), timeout=30)

    # Check that de-opping works (ops.json is mutable as expected)
    server.succeed(server_cmd("deop Misterio7x"))
    server.wait_until_succeeds(grep_logs("Made Misterio7x no longer a server operator"), timeout=3)
  '';
}
