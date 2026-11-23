self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.minecraft-servers;

  inherit (lib)
    attrNames
    filterAttrs
    mapAttrs'
    mapAttrsToList
    mkIf
    mkOption
    optional
    optionalString
    pipe
    types
    ;
  inherit (self.lib)
    mkOpt'
    ;
in
{
  imports = [ self.commonModules.minecraft-servers ];

  options.services.minecraft-servers = {
    # Ideally we'd use the "%D" placeholder here, but that doesn't work with tmpfiles.
    # We'd need a separate unit to create the `WorkingDirectory` before the
    # main service starts, so this feels simpler.
    dataDir = mkOpt' types.str "${config.xdg.dataHome}/minecraft-servers" ''
      Directory to store the Minecraft servers.
      Each server will be under a subdirectory named after
      the server name in this directory, such as <literal>~/.local/share/minecraft-servers/servername</literal>.
    '';

    # Unlike dataDir, we don't necessarily know the user's UID at build time,
    # so use the %t placeholder to locate the correct /run/user/<uid> directory.
    runDir = mkOpt' types.str "%t/minecraft" ''
      Deprecated: Directory to place the runtime tmux sockets into.
      Each server's console will be a tmux socket file in the form of <literal>servername.sock</literal>.
      To connect to the console, run `tmux -S "$XDG_RUNTIME_DIR/minecraft/servername.sock" attach`,
      press `Ctrl + b` then `d` to detach.

      Plase use <option>services.minecraft-servers.managementSystem.tmux.socketPath</option>` instead.
    '';

    servers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enableReload = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Reload server when configuration changes (instead of restart).

                This action re-links/copies the declared symlinks/files. You can
                include additional actions (even in-game commands) by setting
                <option>services.minecraft-servers.<name>.extraReload</option>.

                This option has no effect unless <option>systemd.user.startServices</option> is set to `sd-switch`.
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
      warnings =
        let
          serversWithReload = filterAttrs (name: server: server.enableReload) servers;
        in
        mkIf (serversWithReload != { } && config.systemd.user.startServices != "sd-switch") (
          mapAttrsToList (name: server: ''
            `services.minecraft-servers.${name}.enableReload` has no effect unless `systemd.user.startServices` is set to "sd-switch".
          '') servers
        );

      systemd.user.tmpfiles.rules = (
        mapAttrsToList (name: _: "d '${cfg.dataDir}/${name}' 0770 - - - -") servers
      );

      systemd.user.sockets = pipe servers [
        (filterAttrs (name: server: server._socket != null))
        (mapAttrs' (
          name: server: {
            name = "minecraft-server-${name}";
            value = {
              Unit = {
                Requires = [ "minecraft-server-${name}.service" ];
                PartOf = [ "minecraft-server-${name}.service" ];
              };
              Socket = server._socket.socketConfig;
            };
          }
        ))
      ];

      systemd.user.services = mapAttrs' (
        name: conf:
        let
          service = conf._service;
          socket = optional (conf._socket != null) "minecraft-server-${name}.socket";
        in
        {
          name = "minecraft-server-${name}";
          value = mkIf cfg.enable {
            Install = {
              WantedBy = mkIf conf.autoStart [ "default.target" ];
            };

            Unit = {
              Description = "Minecraft Server ${name}";
              Requires = socket;
              PartOf = socket;
              After = [ "network.target" ] ++ socket;
              StartLimitIntervalSec = 120;
              StartLimitBurst = 5;
            };

            Service = service.serviceConfig // {
              # re-implement NixOS systemd.services.<name>.<environment/path>
              Environment = (
                let
                  path = service.path ++ [
                    pkgs.coreutils
                    pkgs.findutils
                    pkgs.gnugrep
                  ];
                  env = service.environment // {
                    PATH = "${lib.makeBinPath path}:${lib.makeSearchPathOutput "bin" "sbin" path}";
                  };
                in
                map (n: optionalString (env.${n} != null) "${builtins.toJSON "${n}=${env.${n}}"}") (attrNames env)
              );

              # reimplementation of NixOS's `reloadIfChanged`/`restartIfChanged` options
              # handled by `sd-switch`
              ${if conf.enableReload then "X-ReloadIfChanged" else "X-RestartIfChanged"} = true;
            };
          };
        }
      ) servers;
    }
  );
}
