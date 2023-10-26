{ nixosTest, outputs }:

nixosTest {
  name = "simple";
  nodes.server = { config, pkgs, lib, ... }: {
    virtualisation = {
      cores = 2;
      memorySize = 2048;
    };

    nixpkgs = {
      overlays = [ outputs.overlays.default ];
      config.allowUnfree = true;
    };
    imports = [ outputs.nixosModules.default ];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      servers.vanilla = {
        enable = true;
        jvmOpts = "-Xmx512M"; # Avoid OOM
        package = pkgs.vanilla-server;
        serverProperties = {
          server-port = 25565;
          server-ip = "127.0.0.1";
          level-type = "flat"; # Make the test lighter
          max-players = 10;
        };
      };
      velocity = {
        enable = true;
        address = "0.0.0.0";
        jvmArgs = [
          # Not entirely sure why it needs this. Outside tests it doesn't seem to need it
          "-XX:+UnlockExperimentalVMOptions"
        ];
        config = {
          try = [ "vanilla" ];
        };
      };
    };
  };

  testScript = { nodes, ... }: ''
    server.wait_for_unit("velocity.service")
    server.wait_for_open_port(25577)
  '';
}
