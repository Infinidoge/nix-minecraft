{
  config,
  pkgs,
  lib,
  ...
}:
let
  serversCfg = config.services.minecraft-servers.servers;
in

{
  networking.firewall.allowedTCPPorts = [ 25565 ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = false;
    servers = {
      proxy = {
        enable = true;
        jvmOpts = "-Xmx1G -Xms1G";
        package = pkgs.minecraftServers.velocity-server;
        stopCommand = "end";
        files = {
          "velocity.toml".value = {
            config-version = "2.5";
            bind = "0.0.0.0:25565";
            motd = "My cool network";
            online-mode = true;
            servers = {
              survival = "localhost:${toString serversCfg.survival.serverProperties.server-port}";
              try = [ "survival" ];
            };
            # It's safe to use, as long as you don't open the underlying server ports
            player-info-forwarding-mode = "legacy";
          };
        };
      };
      survival = {
        enable = true;
        jvmOpts = "-Xmx4G -Xms4G";
        package = pkgs.minecraftServers.paper-server;
        serverProperties = {
          server-port = 50001;
          # Required by proxy
          online-mode = false;
        };
        files = {
          # Required by proxy
          "spigot.yml".value = {
            settings.bungeecord = true;
          };
          "config/paper-global.yml".value = {
            proxies.bungeecord.online-mode = true;
          };
        };
      };
    };
  };
}
