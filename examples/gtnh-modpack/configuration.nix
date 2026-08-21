{pkgs, ...}: {
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    servers.gtnh = rec {
      enable = true;
      package = pkgs.callPackage ./gtnh.nix { };
      jvmOpts = "-Xmx8G -Xms8G";
      serverProperties = {
        level-type = "rwg";
        difficulty = 3;
        allow-flight = true;
      };
      symlinks.mods = "${package}/lib/mods";
      files.config = "${package}/lib/config";
    };
  };
}
