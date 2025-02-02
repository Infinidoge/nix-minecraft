{ config, pkgs, lib, ... }:

{
  # Minecraft server settings
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    servers.fabric = {
       enable = true;
       jvmOpts = "-Xmx4G -Xms2G";

       # Specify the custom minecraft server package
       package = pkgs.fabricServers.fabric-1_21_1.override { loaderVersion = "0.16.10"; }; # Specific fabric loader version

     };
  };

}
