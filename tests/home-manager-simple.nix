{
  nixosTest,
  inputs,
  outputs,
}:

nixosTest {
  name = "home-manager-simple";
  nodes.server =
    { ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      home-manager.useGlobalPkgs = true;

      users.users.minecraft = {
        isNormalUser = true;
        password = "minecraft";
        group = "users";
        uid = 1000;
        linger = true;
      };

      services.getty.autologinUser = "minecraft";

      home-manager.users.minecraft =
        { pkgs, ... }:
        {
          imports = [
            outputs.homeModules.minecraft-servers
          ];
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

          home.packages = [ pkgs.tmux ];

          systemd.user.startServices = "sd-switch";
          home.stateVersion = "25.05";
        };
    };

  testScript =
    { ... }:
    # python
    ''
      name = "vanilla"
      grep_logs = lambda expr: f"grep '{expr}' /home/minecraft/.local/share/minecraft-servers/{name}/logs/latest.log"

      # wait for login
      machine.wait_for_unit("multi-user.target")

      server.wait_for_unit(f"minecraft-server-{name}.service", user="minecraft")
      server.wait_for_open_port(25565)
      server.wait_until_succeeds(grep_logs("Done ([0-9.]\+s)! For help, type \"help\""), timeout=30)

      # Test default stopCommand/ensure graceful shutdown
      server.stop_job(f"minecraft-server-{name}.service", user="minecraft")
      machine.wait_for_closed_port(25565)
      server.wait_until_succeeds(grep_logs("Stopping server"), timeout=30)
    '';
}
