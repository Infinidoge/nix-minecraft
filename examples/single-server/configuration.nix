{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Minecraft server settings
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    servers.vanilla = {
      enable = true;
      allocatedRAM = "4G";

      # Specify the custom minecraft server package
      package = pkgs.minecraftServers.vanilla-server;
    };
  };
}
