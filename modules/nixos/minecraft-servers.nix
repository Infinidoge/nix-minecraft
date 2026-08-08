self:
{ config, lib, ... }:
let
  cfg = config.services.minecraft-servers;

  inherit (lib)
    filterAttrs
    flatten
    mapAttrs'
    mapAttrsToList
    mkIf
    mkOption
    optional
    pipe
    types
    ;
  inherit (self.lib)
    mkEnableOpt
    mkOpt'
    ;
in
{
  imports = [ self.commonModules.minecraft-servers ];

  options.services.minecraft-servers = {
    dataDir = mkOpt' types.path "/srv/minecraft" ''
      Directory to store the Minecraft servers.
      Each server will be under a subdirectory named after
      the server name in this directory, such as <literal>/srv/minecraft/servername</literal>.
    '';

    runDir = mkOpt' types.path "/run/minecraft" ''
      Deprecated: Directory to place the runtime tmux sockets into.
      Each server's console will be a tmux socket file in the form of <literal>servername.sock</literal>.
      To connect to the console, run `tmux -S /run/minecraft/servername.sock attach`,
      press `Ctrl + b` then `d` to detach.

      Plase use <option>services.minecraft-servers.managementSystem.tmux.socketPath</option>` instead.
    '';

    openFirewall = mkEnableOpt ''
      Whether to open ports in the firewall for each server.
      Sets the default for <option>services.minecraft-servers.servers.<name>.openFirewall</option>.
    '';

    user = mkOption {
      type = types.str;
      default = "minecraft";
      description = ''
        Name of the user to create and run servers under.
        It is recommended to leave this as the default, as it is
        the same user as <option>services.minecraft-server</option>.
      '';
      internal = true;
      visible = false;
    };

    group = mkOption {
      type = types.str;
      default = "minecraft";
      description = ''
        Name of the group to create and run servers under.
        In order to modify the server files your user must be a part of this
        group. If you are using the tmux management system (the default), you also need to be a part of this group to attach to the tmux socket.
        It is recommended to leave this as the default, as it is
        the same group as <option>services.minecraft-server</option>.
      '';
    };

    servers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enableReload = mkOpt' types.bool false ''
              Reload server when configuration changes (instead of restart).

              This action re-links/copies the declared symlinks/files. You can
              include additional actions (even in-game commands) by setting
              <option>services.minecraft-servers.<name>.extraReload</option>.
            '';

            openFirewall = mkOption {
              type = types.bool;
              default = cfg.openFirewall;
              defaultText = "The value of <literal>services.minecraft-servers.openFirewall</literal>";
              description = ''
                Whether to open ports in the firewall for this server.
              '';
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable (
    let
      servers = filterAttrs (_: cfg: cfg.enable) cfg.servers;
    in
    {
      assertions = [
        {
          assertion =
            config.services.minecraft-server.enable -> cfg.dataDir != config.services.minecraft-server.dataDir;
          message =
            "`services.minecraft-servers.dataDir` and `services.minecraft-server.dataDir` conflict."
            + " Set one to use a different data directory.";
        }
      ];

      users = {
        users.minecraft = mkIf (cfg.user == "minecraft") {
          description = "Minecraft server service user";
          home = cfg.dataDir;
          createHome = true;
          homeMode = "770";
          isSystemUser = true;
          group = "minecraft";
        };
        groups.minecraft = mkIf (cfg.group == "minecraft") { };
      };

      networking.firewall =
        let
          toOpen = filterAttrs (_: cfg: cfg.openFirewall) servers;
          # Minecraft and RCON
          getTCPPorts =
            n: c:
            [ c.serverProperties.server-port or 25565 ]
            ++ (optional (c.serverProperties.enable-rcon or false) (c.serverProperties."rcon.port" or 25575));
          # Query
          getUDPPorts =
            n: c:
            optional (c.serverProperties.enable-query or false) (c.serverProperties."query.port" or 25565);
        in
        {
          allowedUDPPorts = flatten (mapAttrsToList getUDPPorts toOpen);
          allowedTCPPorts = flatten (mapAttrsToList getTCPPorts toOpen);
        };

      systemd.tmpfiles.rules = mapAttrsToList (
        name: _: "d '${cfg.dataDir}/${name}' 0770 ${cfg.user} ${cfg.group} - -"
      ) servers;

      systemd.sockets = pipe servers [
        (filterAttrs (name: server: server._socket != null))
        (mapAttrs' (
          name: server: {
            name = "minecraft-server-${name}";
            value = {
              requires = [ "minecraft-server-${name}.service" ];
              partOf = [ "minecraft-server-${name}.service" ];
              socketConfig = server._socket.socketConfig // {
                SocketUser = cfg.user;
                SocketGroup = cfg.group;
              };
            };
          }
        ))
      ];

      systemd.services = mapAttrs' (
        name: conf:
        let
          service = conf._service;
          socket = optional (conf._socket != null) "minecraft-server-${name}.socket";
        in
        {
          name = "minecraft-server-${name}";
          value = {
            description = "Minecraft Server ${name}";
            wantedBy = mkIf conf.autoStart [ "multi-user.target" ];
            requires = socket;
            partOf = socket;
            after = [ "network.target" ] ++ socket;

            enable = conf.enable;

            startLimitIntervalSec = 120;
            startLimitBurst = 5;

            serviceConfig = service.serviceConfig // {
              User = cfg.user;
              Group = cfg.group;

              # Hardening
              CapabilityBoundingSet = [ "" ];
              DeviceAllow = [ "" ];
              LockPersonality = true;
              PrivateDevices = true;
              PrivateTmp = true;
              PrivateUsers = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              RestrictAddressFamilies = [
                "AF_UNIX"
                "AF_INET"
                "AF_INET6"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              UMask = "0007";
            };

            restartIfChanged = !conf.enableReload;
            reloadIfChanged = conf.enableReload;

            inherit (service) path environment;
          };
        }
      ) servers;
    }
  );
}
