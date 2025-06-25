self:
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.services.minecraft-servers;

  inherit (lib)
    concatStringsSep
    count
    escapeShellArg
    filter
    filterAttrs
    getExe
    length
    literalExpression
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    unique
    ;

  inherit (self.lib)
    mkBoolOpt'
    mkEnableOpt
    mkOpt'
    mkReadOnlyOption
    mkService
    ;

  minecraftUUID =
    types.strMatching "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
    // {
      description = "Minecraft UUID";
    };

  configType = types.submodule {
    options = {
      format = mkOption {
        type = with types; nullOr attrs;
        default = null;
        description = ''
          The format to use when converting "value" into a file. If set to
          null (the default), we'll try to infer it from the file name.
        '';
        example = literalExpression "pkgs.formats.yaml { }";
      };
      value = mkOption {
        type = with types; either (attrsOf anything) (listOf anything);
        description = ''
          A value that can be converted into the specified format.
        '';
      };
    };
  };

  managementSystem = types.submodule (
    args:
    let
      ms = args.config;
    in
    {
      options = {
        tmux = {
          enable = mkEnableOption "management via a TMUX socket";
          socketPath = mkOption {
            type =
              with types;
              functionTo (oneOf [
                path
                str
              ]);
            description = ''
              Function from a server name to the path at which the server's tmux socket is placed.
              To connect to the console, run `tmux -S <path to socket> attach`,
              press `Ctrl + b` then `d` to detach.

              Note that while currently the default respects <option>services.minecraft-servers.runDir</option>,
              that option is deprecated and will be removed.
              The default will then change to `name: "/run/minecraft/''${name}.sock`.
            '';
            default = name: "${cfg.runDir}/${name}.sock";
            defaultText = literalExpression ''name: "''${cfg.runDir}/''${name}.sock"'';
          };
          _config = mkReadOnlyOption (
            name: server:
            let
              tmux = "${pkgs.tmux}/bin/tmux";
            in
            {
              serviceConfig = {
                Type = "forking";
                GuessMainPID = true;
              };
              environment = {
                # let systemd expand % placeholders
                STDIN_SOCKET_PATH = ms.tmux.socketPath name;
              };
              hooks = {
                start = ''
                  ${tmux} -S "$STDIN_SOCKET_PATH" new -d ${getExe server.package} ${server.jvmOpts}

                  # HACK: PrivateUsers makes every user besides root/minecraft `nobody`, so this restores old tmux behavior
                  # See https://github.com/Infinidoge/nix-minecraft/issues/5
                  ${tmux} -S "$STDIN_SOCKET_PATH" server-access -aw nobody
                '';
                postStart = ''
                  ${pkgs.coreutils}/bin/chmod 660 "$STDIN_SOCKET_PATH"
                '';
                stop = ''
                  function server_running {
                    ${tmux} -S "$STDIN_SOCKET_PATH" has-session
                  }

                  if ! server_running ; then
                    exit 0
                  fi

                  ${tmux} -S "$STDIN_SOCKET_PATH" send-keys ${escapeShellArg server.stopCommand} Enter

                  while server_running; do sleep 1s; done
                '';
              };
            }
          );
        };

        systemd-socket = {
          enable = mkEnableOpt "management through the systemd journal & a command socket";
          stdinSocket = {
            path = mkOption {
              type =
                with types;
                functionTo (oneOf [
                  path
                  str
                ]);
              description = ''
                Function from a server name to the path at which the server's stdin socket is placed.
                You can send the server commands by writing to this socket,
                for example with shell redirection: `echo 'list' > <path to socket>`.

                Note that while currently the default respects <option>services.minecraft-servers.runDir</option>,
                that option is deprecated and will be removed.
                The default will then change to `name: "/run/minecraft/''${name}.stdin`.
              '';
              default = name: "${cfg.runDir}/${name}.stdin";
              defaultText = literalExpression ''name: "''${cfg.runDir}/''${name}.stdin"'';
            };
            mode = mkOption {
              type = types.strMatching "[0-7]{4}";
              description = "Access mode of the socket file in octal notation";
              default = "0660";
            };
          };
          _config = mkReadOnlyOption (
            name: server: {
              serviceConfig = {
                Type = "simple";
                StandardInput = "socket";
                StandardOutput = "journal";
                StandardError = "journal";
              };
              environment = {
                # let systemd expand % placeholders
                STDIN_SOCKET_PATH = ms.systemd-socket.stdinSocket.path name;
              };
              hooks = {
                start = ''
                  ${getExe server.package} ${server.jvmOpts}
                '';
                postStart = "";
                stop = ''
                  ${optionalString (server.stopCommand != null) ''
                    echo ${escapeShellArg server.stopCommand} > "$STDIN_SOCKET_PATH"

                    while kill -0 "$1" 2> /dev/null; do sleep 1s; done
                  ''}
                '';
              };
            }
          );
        };

        _config = mkOption {
          internal = true;
          default = if ms.tmux.enable then ms.tmux._config else ms.systemd-socket._config;
        };
      };
    }
  );
in
{
  options.services.minecraft-servers = {
    enable = mkEnableOpt ''
      If enabled, the servers in <option>services.minecraft-servers.servers</option>
      will be created and started as applicable.
      The data for the servers will be loaded from and
      saved to <option>services.minecraft-servers.dataDir</option>
    '';

    eula = mkEnableOpt ''
      Whether you agree to
      <link xlink:href="https://account.mojang.com/documents/minecraft_eula">
      Mojang's EULA</link>. This option must be set to
      <literal>true</literal> to run Minecraft server.
    '';

    environmentFile = mkOpt' (types.nullOr types.path) null ''
      File consisting of lines in the form varname=value to define environment
      variables for the minecraft servers.

      Secrets (database passwords, secret keys, etc.) can be provided to server
      files without adding them to the Nix store by defining them in the
      environment file and referring to them in option
      <option>services.minecraft-servers.servers.<name>.files</option> with the
      syntax @varname@.
    '';

    managementSystem = mkOption {
      type = managementSystem;
      description = ''
        The default management system for all servers.
      '';
      default = {
        tmux.enable = true;
      };
      example = ''
        {
          tmux.enable = false;
          systemd-socket.enable = true;
        }
      '';
    };

    servers = mkOption {
      default = { };
      description = ''
        Servers to create and manage using this module.
        Each server can be stopped with <literal>systemctl stop minecraft-server-servername</literal>.
        ::: {.warning}
        If the server is not stopped using `systemctl`, the service will automatically restart the server.
        See <option>services.minecraft-servers.servers.<name>.restart</option>.
        :::
      '';
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          {
            options = {
              enable = mkEnableOpt ''
                Whether to enable this server.
                If set to <literal>false</literal>, does NOT delete any data in the data directory,
                just does not generate the service file.
              '';

              autoStart = mkBoolOpt' true ''
                Whether to start this server on boot.
                If set to <literal>false</literal>, can still be started with
                <literal>systemctl start minecraft-server-servername</literal>.
                Requires the server to be enabled.
              '';

              restart = mkOpt' types.str "always" ''
                Value of systemd's <literal>Restart=</literal> service configuration option.
                If you are using the tmux management system (the default), values other than
                <literal>"no"</literal> and <literal>"always"</literal> may not work properly.
                As a consequence of the <literal>"always"</literal> option, stopping the server
                in-game with the <literal>stop</literal> command will cause the server to automatically restart.
              '';

              extraReload = mkOpt' types.lines "" ''
                Extra commands to run when reloading the service. Only has an
                effect if
                <option>services.minecraft-servers.<name>.enableReload</option> is
                true.
              '';

              extraStartPre = mkOpt' types.lines "" ''
                Extra commands to run before starting the service.
              '';

              extraStartPost = mkOpt' types.lines "" ''
                Extra commands to run after starting the service.
              '';

              extraStopPre = mkOpt' types.lines "" ''
                Extra commands to run before stopping the service.
              '';

              extraStopPost = mkOpt' types.lines "" ''
                Extra commands to run after stopping the service.
              '';

              stopCommand = mkOption {
                type = types.nullOr types.str;
                description = ''
                  Console command to run when cleanly stopping the server (ExecStop).
                  Defaults to <literal>stop</literal>, which works for most servers.
                  For proxies (bungeecord, velocity), you should set
                  <literal>end</literal>.

                  If set to <literal>null</literal>, the server will be stopped by
                  systemd without issuing any command.
                '';
                default = "stop";
              };

              whitelist = mkOption {
                type = types.attrsOf minecraftUUID;
                default = { };
                description = ''
                  Whitelisted players, only has an effect when
                  enabled via <option>services.minecraft-servers.<name>.serverProperties</option>
                  by setting <literal>white-list</literal> to <literal>true</literal.

                  To use a non-declarative whitelist, enable the whitelist and don't fill in this value.
                  As long as it is empty, no whitelist file is generated.
                '';
                example = literalExpression ''
                  {
                    username1 = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
                    username2 = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy";
                  }
                '';
              };

              operators = mkOption {
                type = types.attrsOf (
                  types.coercedTo minecraftUUID (v: { uuid = v; }) (
                    types.submodule {
                      options = {
                        uuid = mkOption {
                          type = minecraftUUID;
                          description = "The operator's UUID";
                          example = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
                        };
                        level = mkOption {
                          type = types.ints.between 0 4;
                          description = "The operator's permission level";
                          default = 4;
                        };
                        bypassesPlayerLimit = mkOption {
                          type = types.bool;
                          description = "If true, the operator can join the server even if the player limit has been reached";
                          default = false;
                        };
                      };
                    }
                  )
                );
                default = { };
                description = ''
                  Server operators. See <link xlink:href="https://minecraft.wiki/w/Ops.json_format"/>.

                  To use a non-declarative operator list, don't fill in this value.
                  As long as it is empty, no operators file is generated.
                '';
                example = literalExpression ''
                  {
                    username1 = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
                    username2 = {
                      uuid = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy";
                      level = 3;
                      bypassesPlayerLimit = true;
                    };
                  }
                '';
              };

              serverProperties = mkOption {
                type =
                  with types;
                  attrsOf (oneOf [
                    bool
                    int
                    str
                  ]);
                default = { };
                example = literalExpression ''
                  {
                    server-port = 43000;
                    difficulty = 3;
                    gamemode = 1;
                    max-players = 5;
                    motd = "NixOS Minecraft server!";
                    white-list = true;
                    enable-rcon = true;
                    "rcon.password" = "hunter2";
                  }
                '';
                description = ''
                  Minecraft server properties for the server.properties file of this server. See
                  <link xlink:href="https://minecraft.gamepedia.com/Server.properties#Java_Edition_3"/>
                  for documentation on these values.

                  To use a non-declarative server.properties, don't fill in this value.
                  As long as it is empty, no server.properties file is generated.
                '';
              };

              package = mkOption {
                description = "The Minecraft server package to use.";
                type = types.package;
                default = pkgs.minecraft-server;
                defaultText = literalExpression "pkgs.minecraft-server";
                example = "pkgs.minecraftServers.vanilla-1_18_2";
              };

              jvmOpts = mkOpt' (
                with types; coercedTo (listOf str) (lib.concatStringsSep " ") (separatedString " ")
              ) "-Xmx2G -Xms1G" "JVM options for this server.";

              path =
                with types;
                mkOpt' (listOf (either path str)) [ ] ''
                  Packages added to the Minecraft server's <literal>PATH</literal> environment variable.
                  Works as <option>systemd.services.<name>.path</option>.
                '';

              environment =
                with types;
                mkOpt'
                  (attrsOf (
                    nullOr (oneOf [
                      str
                      path
                      package
                    ])
                  ))
                  { }
                  ''
                    Environment variables added to the Minecraft server's processes.
                    Works as <option>systemd.services.<name>.environment</option>.
                  '';

              symlinks =
                with types;
                mkOpt' (attrsOf (either path configType)) { } ''
                  Things to symlink into this server's data directory, in the form of
                  a nix package/derivation. Can be used to declaratively manage
                  arbitrary files in the server's data directory.
                '';
              files =
                with types;
                mkOpt' (attrsOf (either path configType)) { } ''
                  Things to copy into this server's data directory. Similar to symlinks,
                  but these are actual, writable, files. Useful for configuration files
                  that don't behave well when read-only. Directories are copied recursively and
                  dereferenced. They will be deleted after the server stops, so any modification
                  is discarded.

                  These files may include placeholders to substitute with values from
                  <option>services.minecraft-servers.environmentFile</option>
                  (i.e. @variable_name@).
                '';

              managementSystem = mkOption {
                type = types.submodule (managementSystem.getSubModules);
                description = ''
                  Configuration for the system used to manage this server. Overrides the global configuration on an option-by-option basis.
                '';
                default = cfg.managementSystem;
                example = options.services.minecraft-servers.managementSystem.example;
              };

              _socket = mkReadOnlyOption (
                let
                  socket = config.managementSystem.systemd-socket;
                in
                if socket.enable then
                  {
                    name = "minecraft-server-${name}.socket";
                    socketConfig = {
                      ListenFIFO = socket.stdinSocket.path name;
                      SocketMode = socket.stdinSocket.mode;
                      RemoveOnStop = true;
                      FlushPending = true;
                    };
                  }
                else
                  null
              );

              _service = mkReadOnlyOption (mkService {
                inherit
                  pkgs
                  lib
                  name
                  cfg
                  ;
              });
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable (
    let
      servers = filterAttrs (_: cfg: cfg.enable) cfg.servers;
    in
    {
      assertions =
        [
          {
            assertion = cfg.eula;
            message =
              "You must agree to Mojangs EULA to run minecraft-servers."
              + " Read https://account.mojang.com/documents/minecraft_eula and"
              + " set `services.minecraft-servers.eula` to `true` if you agree.";
          }
          {
            assertion =
              let
                serverPorts = mapAttrsToList (name: conf: conf.serverProperties.server-port or 25565) servers;
                counts = map (port: count (x: x == port) serverPorts) (unique serverPorts);
              in
              lib.all (x: x == 1) counts;
            message = "Multiple servers are set to use the same port. Change one to use a different port.";
          }
        ]
        ++ (mapAttrsToList (
          name: conf:
          let
            enabled = filter (name: conf.managementSystem.${name}.enable) [
              "tmux"
              "systemd-socket"
            ];
          in
          {
            assertion = length enabled == 1;
            message = "Exactly one server management system must be enabled for ${name}, got: [${concatStringsSep ", " enabled}]}";
          }
        ) servers);

      warnings = lib.optional (cfg.runDir != options.services.minecraft-servers.runDir.default) ''
        `runDir` has been deprecated.

        Please use `services.minecraft-servers.managementSystem.tmux.socketPath` instead.
        For example, `name: "${cfg.runDir}/''${name}.sock"`.

        See the changelog file for more information.
      '';
    }
  );
}
