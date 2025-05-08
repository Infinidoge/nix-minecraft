{
  config,
  lib,
  options,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.minecraft-servers;

  mkOpt = type: default: mkOption { inherit type default; };

  mkOpt' =
    type: default: description:
    mkOption { inherit type default description; };

  mkBoolOpt =
    default:
    mkOption {
      inherit default;
      type = types.bool;
      example = true;
    };

  mkBoolOpt' =
    default: description:
    mkOption {
      inherit default description;
      type = types.bool;
      example = true;
    };

  normalizeFiles = files: mapAttrs configToPath (filterAttrs (_: nonEmptyValue) files);
  nonEmptyValue = x: nonEmpty x && (x ? value -> nonEmpty x.value);
  nonEmpty = x: x != { } && x != [ ];

  configToPath =
    name: config:
    if
      isStringLike config # Includes paths and packages
    then
      config
    else
      (getFormat name config).generate name config.value;
  getFormat =
    name: config: if config ? format && config.format != null then config.format else inferFormat name;
  inferFormat =
    name:
    let
      error = throw "nix-minecraft: Could not infer format from file '${name}'. Specify one using 'format'.";
      extension = builtins.match "[^.]*\\.(.+)" name;
    in
    if extension != null && extension != [ ] then
      formatExtensions.${head extension} or error
    else
      error;

  txtList =
    { }:
    {
      type = with lib.types; listOf str;
      generate = name: value: pkgs.writeText name (lib.concatStringsSep "\n" value);
    };

  formatExtensions = with pkgs.formats; {
    "yml" = yaml { };
    "yaml" = yaml { };
    "json" = json { };
    "props" = keyValue { };
    "properties" = keyValue { };
    "toml" = toml { };
    "ini" = ini { };
    "txt" = txtList { };
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

  managementSystem = types.submodule {
    options = {
      tmux = {
        enable = mkEnableOption "management via a TMUX socket";
        socketPath = mkOption {
          type = with types; functionTo path;
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
      };
      systemd-socket = {
        enable = mkEnableOpt "management through the systemd journal & a command socket";
        stdinSocket = {
          path = mkOption {
            type = with types; functionTo path;
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
      };
    };
  };

  managementSystemConfig =
    name: server:
    let
      ms = server.managementSystem;
      tmux = "${getBin pkgs.tmux}/bin/tmux";
    in
    assert assertMsg (
      !(ms.tmux.enable && ms.systemd-socket.enable)
    ) "Only one server management system can be enabled at a time.";
    if ms.tmux.enable then
      let
        sock = ms.tmux.socketPath name;
      in
      {
        serviceConfig = {
          Type = "forking";
          GuessMainPID = true;
        };
        hooks = {
          start = ''
            ${tmux} -S ${sock} new -d ${getExe server.package} ${server.jvmOpts}

            # HACK: PrivateUsers makes every user besides root/minecraft `nobody`, so this restores old tmux behavior
            # See https://github.com/Infinidoge/nix-minecraft/issues/5
            ${tmux} -S ${sock} server-access -aw nobody
          '';
          postStart = ''
            ${pkgs.coreutils}/bin/chmod 660 ${sock}
          '';
          stop = ''
            function server_running {
              ${tmux} -S ${sock} has-session
            }

            if ! server_running ; then
              exit 0
            fi

            ${tmux} -S ${sock} send-keys ${escapeShellArg server.stopCommand} Enter

            while server_running; do sleep 1s; done
          '';
        };
      }
    else if ms.systemd-socket.enable then
      {
        serviceConfig = {
          Type = "simple";
          StandardInput = "socket";
          StandardOutput = "journal";
          StandardError = "journal";
        };
        hooks = {
          start = ''
            ${getExe server.package} ${server.jvmOpts}
          '';
          postStart = "";
          stop = ''
            ${optionalString (server.stopCommand != null) ''
              echo ${escapeShellArg server.stopCommand} > ${escapeShellArg (ms.systemd-socket.stdinSocket.path name)}

              while kill -0 "$1" 2> /dev/null; do sleep 1s; done
            ''}
          '';
        };
      }
    else
      builtins.throw "At least one server management system must be enabled.";

  mkEnableOpt = description: mkBoolOpt' false description;
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

    openFirewall = mkEnableOpt ''
      Whether to open ports in the firewall for each server.
      Sets the default for <option>services.minecraft-servers.servers.<name>.openFirewall</option>.
    '';

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
          { name, ... }:
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

              openFirewall = mkOption {
                type = types.bool;
                default = cfg.openFirewall;
                defaultText = "The value of <literal>services.minecraft-servers.openFirewall</literal>";
                description = ''
                  Whether to open ports in the firewall for this server.
                '';
              };

              restart = mkOpt' types.str "always" ''
                Value of systemd's <literal>Restart=</literal> service configuration option.
                If you are using the tmux management system (the default), values other than
                <literal>"no"</literal> and <literal>"always"</literal> may not work properly.
                As a consequence of the <literal>"always"</literal> option, stopping the server
                in-game with the <literal>stop</literal> command will cause the server to automatically restart.
              '';

              enableReload = mkOpt' types.bool false ''
                Reload server when configuration changes (instead of restart).

                This action re-links/copies the declared symlinks/files. You can
                include additional actions (even in-game commands) by setting
                <option>services.minecraft-servers.<name>.extraReload</option>.
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
                type =
                  let
                    minecraftUUID =
                      types.strMatching "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
                      // {
                        description = "Minecraft UUID";
                      };
                  in
                  types.attrsOf minecraftUUID;
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
                type =
                  let
                    minecraftUUID =
                      types.strMatching "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
                      // {
                        description = "Minecraft UUID";
                      };
                  in
                  types.attrsOf (
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
                type = types.submodule (
                  managementSystem.getSubModules
                  ++ [
                    { config = mkDefault cfg.managementSystem; }
                  ]
                );
                description = ''
                  Configuration for the system used to manage this server. Overrides the global configuration on an option-by-option basis.
                '';
                default = { };
                example = options.services.minecraft-servers.managementSystem.example;
              };
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

      assertions = [
        {
          assertion = cfg.eula;
          message =
            "You must agree to Mojangs EULA to run minecraft-servers."
            + " Read https://account.mojang.com/documents/minecraft_eula and"
            + " set `services.minecraft-servers.eula` to `true` if you agree.";
        }
        {
          assertion =
            config.services.minecraft-server.enable -> cfg.dataDir != config.services.minecraft-server.dataDir;
          message =
            "`services.minecraft-servers.dataDir` and `services.minecraft-server.dataDir` conflict."
            + " Set one to use a different data directory.";
        }
        {
          assertion =
            let
              serverPorts = mapAttrsToList (name: conf: conf.serverProperties.server-port or 25565) (
                filterAttrs (_: cfg: cfg.openFirewall) servers
              );

              counts = map (port: count (x: x == port) serverPorts) (unique serverPorts);
            in
            lib.all (x: x == 1) counts;
          message = "Multiple servers are set to use the same port. Change one to use a different port.";
        }
      ];

      warnings = lib.optional (cfg.runDir != options.services.minecraft-servers.runDir.default) ''
        `runDir` has been deprecated.

        Please use `services.minecraft-servers.managementSystem.tmux.socketPath` instead.
        For example, `name: "${cfg.runDir}/''${name}.sock"`.

        See the changelog file for more information.
      '';

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
        (filterAttrs (name: server: server.managementSystem.systemd-socket.enable))
        (mapAttrs' (
          name: server: {
            name = "minecraft-server-${name}";
            value = {
              requires = [ "minecraft-server-${name}.service" ];
              partOf = [ "minecraft-server-${name}.service" ];
              socketConfig =
                let
                  socketConf = server.managementSystem.systemd-socket.stdinSocket;
                in
                {
                  ListenFIFO = socketConf.path name;
                  SocketMode = socketConf.mode;
                  SocketUser = cfg.user;
                  SocketGroup = cfg.group;
                  RemoveOnStop = true;
                  FlushPending = true;
                };
            };
          }
        ))
      ];

      systemd.services = mapAttrs' (
        name: conf:
        let
          symlinks = normalizeFiles (
            {
              "eula.txt".value = {
                eula = true;
              };
              "eula.txt".format = pkgs.formats.keyValue { };
            }
            // conf.symlinks
          );
          files = normalizeFiles (
            {
              "whitelist.json".value = mapAttrsToList (n: v: {
                name = n;
                uuid = v;
              }) conf.whitelist;
              "ops.json".value = mapAttrsToList (n: v: {
                name = n;
                uuid = v.uuid;
                level = v.level;
                bypassesPlayerLimit = v.bypassesPlayerLimit;
              }) conf.operators;
              "server.properties".value = conf.serverProperties;
            }
            // conf.files
          );

          msConfig = managementSystemConfig name conf;

          markManaged = file: ''echo "${file}" >> .nix-minecraft-managed'';
          cleanAllManaged = ''
            if [ -e .nix-minecraft-managed ]; then
              readarray -t to_delete < .nix-minecraft-managed
              rm -rf "''${to_delete[@]}"
              rm .nix-minecraft-managed
            fi
          '';

          ExecStartPre =
            let
              backup = file: ''
                if [[ -e "${file}" ]]; then
                  echo "${file} already exists, moving"
                  mv "${file}" "${file}.bak"
                fi
              '';
              mkSymlinks = concatStringsSep "\n" (
                mapAttrsToList (n: v: ''
                  ${backup n}
                  mkdir -p "$(dirname "${n}")"

                  ln -sf "${v}" "${n}"

                  ${markManaged n}
                '') symlinks
              );

              mkFiles = concatStringsSep "\n" (
                mapAttrsToList (n: v: ''
                  ${backup n}
                  mkdir -p "$(dirname "${n}")"

                  # If it's not a binary, substitute env vars. Else, copy it normally
                  if ${pkgs.file}/bin/file --mime-encoding "${v}" | grep -v '\bbinary$' -q; then
                    ${pkgs.gawk}/bin/awk '{
                      for(varname in ENVIRON)
                        gsub("@"varname"@", ENVIRON[varname])
                      print
                    }' "${v}" > "${n}"
                  else
                    cp -r --dereference "${v}" -T "${n}"
                    chmod +w -R "${n}"
                  fi

                  ${markManaged n}
                '') files
              );
            in
            getExe (
              pkgs.writeShellApplication {
                name = "minecraft-server-${name}-start-pre";
                text = ''
                  ${cleanAllManaged}
                  ${mkSymlinks}
                  ${mkFiles}
                  ${conf.extraStartPre}
                '';
              }
            );

          ExecStart = getExe (
            pkgs.writeShellApplication {
              name = "minecraft-server-${name}-start";
              text = ''
                ${msConfig.hooks.start}
              '';
            }
          );

          ExecStartPost = getExe (
            pkgs.writeShellApplication {
              name = "minecraft-server-${name}-start-post";
              text = ''
                ${msConfig.hooks.postStart}
                ${conf.extraStartPost}
              '';
            }
          );

          execStopScript = getExe (
            pkgs.writeShellApplication {
              name = "minecraft-server-${name}-stop";
              text = ''
                # systemd has no ExecStopPre hook, so we just run it here.
                ${conf.extraStopPre}

                ${msConfig.hooks.stop}
              '';
            }
          );

          ExecStopPost = getExe (
            pkgs.writeShellApplication {
              name = "minecraft-server-${name}-stop-post";
              text = ''
                ${cleanAllManaged}
                ${conf.extraStopPost}
              '';
            }
          );

          ExecReload = getExe (
            pkgs.writeShellApplication {
              name = "minecraft-server-${name}-reload";
              text = ''
                ${ExecStopPost}
                ${ExecStartPre}
                ${conf.extraReload}
              '';
            }
          );
        in
        {
          name = "minecraft-server-${name}";
          value = {
            description = "Minecraft Server ${name}";
            wantedBy = mkIf conf.autoStart [ "multi-user.target" ];
            requires = optional conf.managementSystem.systemd-socket.enable "minecraft-server-${name}.socket";
            partOf = optional conf.managementSystem.systemd-socket.enable "minecraft-server-${name}.socket";
            after = [
              "network.target"
            ] ++ optional conf.managementSystem.systemd-socket.enable "minecraft-server-${name}.socket";

            enable = conf.enable;

            startLimitIntervalSec = 120;
            startLimitBurst = 5;

            serviceConfig = {
              inherit
                ExecStartPre
                ExecStart
                ExecStartPost
                ExecStopPost
                ExecReload
                ;
              ExecStop = "${execStopScript} $MAINPID";

              # the Minecraft server (as of 1.20.6) has a 60s timeout for saving each world.
              # let's let it handle potential lock-ups by itself before resorting to killing it.
              TimeoutStopSec = "1min 15s";

              Restart = conf.restart;
              WorkingDirectory = "${cfg.dataDir}/${name}";
              User = cfg.user;
              Group = cfg.group;
              EnvironmentFile = mkIf (cfg.environmentFile != null) (toString cfg.environmentFile);

              # Default directory for management sockets
              RuntimeDirectory = "minecraft";
              RuntimeDirectoryPreserve = "yes";

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
            } // msConfig.serviceConfig;

            restartIfChanged = !conf.enableReload;
            reloadIfChanged = conf.enableReload;

            inherit (conf) path environment;
          };
        }
      ) servers;
    }
  );
}
