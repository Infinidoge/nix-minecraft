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
       package = pkgs.fabricServers.fabric-1_20_1.override { loaderVersion = "0.16.9"; }; # Specific fabric loader version

       symlinks = {
          mods = pkgs.linkFarmFromDrvs "mods" (builtins.attrValues {
            BetterMC = pkgs.fetchurl { url = "https://cdn.modrinth.com/data/shFhR8Vx/versions/Ur9uoHH5/Better%20MC%20%5BFABRIC%5D%20-%20BMC2%20v26.5.mrpack"; sha512 = "014f93917b238267ccf0b1644fdef722f2fbc18ce78fe28012d8932612b5ac0573b3f93fa7a990cf2516071e799856291805f2114b3e2cf7330c7eb22b77f1f3";>
          });
       };
     };
  };

}
