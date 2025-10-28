pkgs:
let
  lib = pkgs.lib.extend (
    _: _: {
      our = import ../lib { inherit (pkgs) lib; };
    }
  );

  # Include build support functions in callPackage,
  # and include callPackage in itself so it passes to children
  callPackage = pkgs.newScope (
    {
      inherit lib callPackage;
    }
    // buildSupport
  );

  buildSupport = builtins.mapAttrs (n: v: callPackage v) (lib.our.rakeLeaves ./build-support);
in
rec {
  vanillaServers = callPackage ./vanilla-servers { };
  fabricServers = callPackage ./fabric-servers { inherit vanillaServers; };
  quiltServers = callPackage ./quilt-servers { inherit vanillaServers; };
  legacyFabricServers = callPackage ./legacy-fabric-servers { inherit vanillaServers; };
  paperServers = callPackage ./paper-servers { inherit vanillaServers; };
  purpurServers = callPackage ./purpur-servers { inherit vanillaServers; };
  velocityServers = callPackage ./velocity-servers { };

  minecraftServers = lib.mergeAttrsList [
    vanillaServers
    fabricServers
    quiltServers
    legacyFabricServers
    paperServers
    purpurServers
  ];

  vanilla-server = vanillaServers.vanilla;
  fabric-server = fabricServers.fabric;
  quilt-server = quiltServers.quilt;
  paper-server = paperServers.paper;
  purpur-server = purpurServers.purpur;
  velocity-server = velocityServers.velocity;
  minecraft-server = vanilla-server;
}
// (builtins.mapAttrs (n: v: callPackage v { }) (lib.our.rakeLeaves ./tools))
