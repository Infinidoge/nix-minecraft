{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.minecraft-servers.velocity;
  config-version = "2.6";

  mkBoolOpt' = default: description: mkOption {
    inherit default;
    description = mdDoc description;
    type = types.bool;
    example = true;
  };
in
{
  options.services.minecraft-servers.velocity = {
    enable = mkEnableOption "Velocity Minecraft Proxy Server";

    autoStart = mkBoolOpt' true ''
      Whether to start Velocity on boot.
      If set to <literal>false</literal>, can still be started with
      <literal>systemctl start velocity</literal>.
    '';

    datadir = mkOption {
      type = types.str;
      default = "/var/lib/velocity";
      description = mdDoc ''
        Directory to store the Velocity server.
      '';
    };

    openFirewall = mkBoolOpt' false "Whether to open the velocity listen/query ports";

    package = mkOption {
      description = "The Velocity proxy package to use.";
      type = types.package;
      default = pkgs.velocity-server;
      defaultText = literalExpression "pkgs.velocity-server";
    };

    address = mkOption {
      type = with types; nullOr str;
      default = null;
      description = mdDoc ''
        This tells the proxy to accept connections on a specific IP.
        By default, Velocity will listen for connections on all IP
        addresses on the computer on port 25577.
      '';
    };
    port = mkOption {
      type = types.port;
      default = 25577;
      description = mdDoc ''
        Port on which to the proxy will listen for connections

        This only has an affect if <option>services.minecraft-servers.velocity.address</option>
        is non-null.
      '';
    };

    config = {
      motd = mkOption {
        type = with types; nullOr str;
        default = null;
        description = mdDoc ''
          This allows you to change the message shown to players
          when they add your server to their server list.
           
          You can use [MiniMessage format](https://docs.advntr.dev/minimessage/format.html).
        '';
      };
      show-max-players = mkOption {
        type = with types; nullOr int;
        default = null;
        description = mdDoc ''
          This allows you to customize the number of "maximum" players in the player's server list.
          
          Note that Velocity doesn't have a maximum number of players it supports.
        '';
      };
      online-mode = mkBoolOpt' true ''
        Whether to authenticate players with Mojang.
      '';
      force-key-authentication = mkBoolOpt' true ''
        Whether the proxy will enforce the new public key security standard.
      '';
      prevent-client-proxy-connections = mkBoolOpt' false ''
        If client's ISP/AS sent from this proxy is different from
        the one from Mojang's authentication server, the player is kicked.

        This disallows some VPN and proxy connections but is a weak form of protection.
      '';
      forwarding-secret-file = mkOption {
        type = types.str;
        default = "${cfg.datadir}/forwarding.secret";
        defaultText = literalExpression "\${cfg.datadir}/forwarding.secret";
        description = mdDoc ''
          The name of the file in which the forwarding secret is stored.
          This secret is used to ensure that player info forwarded by Velocity 
          comes from your proxy and not from someone pretending to run Velocity. 
          
          See the [Player info forwarding]https://docs.papermc.io/velocity/player-information-forwarding)
          section for more info.

          If file doesn't exist, one will be created with random contents as specified path
          and file mode 400.
        '';
      };
      announce-forge = mkBoolOpt' false ''
        This setting determines whether Velocity should present
        itself as a Forge/FML-compatible server.
      '';
      kick-existing-players = mkBoolOpt' false ''
        Allows restoring the vanilla behavior of kicking users on the proxy if they try to reconnect
        (e.g. lost internet connection briefly).
      '';
      ping-passthrough = mkOption {
        type = types.enum [ "DISABLED" "MODS" "DESCRIPTION" "ALL" ];
        default = "DISABLED";
        description = mdDoc ''
          Allows forwarding nothing (`DISABLED`), the `MOD` (for Forge), the `DESCRIPTION`,
          or everything (`ALL`) from the try list (or forced host server connection order).
        '';
      };
      enable-player-address-logging = mkBoolOpt' true ''
        If disabled (default is true),
        player IP addresses will be replaced by `<ip address withheld>` in logs.
      '';

      servers = mkOption {
        type = with types; nullOr (attrsOf str);
        default = null;
        description = mdDoc ''
          Attribute set of server names to addresses. These addresses can be used later in
          <option>services.minecraft-servers.velocity.config.servers.try</option> or
          <option>services.minecraft-servers.velocity.config.forced-hosts</option>

          If null, auto-generate server list based off 
          <option>services.minecraft-servers.servers</option>
        '';
      };
      try = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        description = mdDoc ''
          This specifies what servers Velocity should try to connect to upon player login
          and when a player is kicked from a server.
        '';
      };

      forced-hosts = mkOption {
        type = with types; attrsOf (listOf str);
        default = { };
        description = mdDoc ''
          This configures the proxy to create a forced host for the specified hostname.
          An array of servers to try for the specified hostname is the value.
        '';
      };

      query = {
        enabled = mkBoolOpt' false ''
          Whether or not Velocity should reply to Minecraft query protocol requests.
          You can usually leave this false.
        '';
        port = mkOption {
          type = types.port;
          default = 25565;
          description = mdDoc ''
            Specifies which port that Velocity should listen on for GameSpy 4 (Minecraft query protocol) requests.
          '';
        };
        map = mkOption {
          type = types.str;
          default = "Velocity";
          description = mdDoc ''
            Specifies the map name to be shown to clients.
          '';
        };
        show-plugins = mkBoolOpt' false ''
          Whether or not Velocity plugins are included in the query responses.
        '';
      };
    };

    extraConfig = mkOption {
      type = with types; attrsOf anything;
      default = { };
      description = mdDoc ''
        Additional config that will be added to the config generated by
        <option>services.minecraft-servers.velocity.config</option>
      '';
    };

    jvmArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = mdDoc ''
        Arguments passed to the JVM
      '';
      example = [
        "-Xms1G"
        "-Xmx1G"
        "-XX:+UseG1GC"
        "-XX:G1HeapRegionSize=4M"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+ParallelRefProcEnabled"
        "-XX:+AlwaysPreTouch"
        "-XX:MaxInlineLevel=15"
      ];
    };
  };

  config = mkIf cfg.enable (
    let
      bind =
        if cfg.address == null
        then null
        else "${cfg.address}:${toString cfg.port}";
      servers =
        if cfg.config.servers != null
        then cfg.config.servers
        else
          mapAttrs
            (_: conf: "127.0.0.1:${toString (conf.serverProperties.server-port or 25565)}")
            config.services.minecraft-servers.servers;
      servers_try = cfg.config.try;
      mergedConfig = {
        inherit bind config-version;
        servers = servers // {
          try = servers_try;
        };
      } // (removeAttrs cfg.config [ "try" "servers" ])
      // cfg.extraConfig;
      filtered = filterAttrsRecursive
        (_: value: value != null)
        mergedConfig;
      configFile = (pkgs.formats.toml { }).generate "velocity.toml" filtered;

      tmux = "${getBin pkgs.tmux}/bin/tmux";
      tmuxSock = "${cfg.datadir}/velocity.sock";

      startScript = pkgs.writeScript "velocity-start" ''
        #!${pkgs.runtimeShell}

        umask u=rwx,g=rwx,o=rx
        ${tmux} -S ${tmuxSock} new -d ${getExe cfg.package} ${concatStringsSep " " cfg.jvmArgs}
      '';

      stopScript = pkgs.writeScript "velocity-stop" ''
        #!${pkgs.runtimeShell}

        if ! [ -d "/proc/$1" ]; then
          exit 0
        fi

        ${tmux} -S ${tmuxSock} send-keys stop Enter
      '';
    in
    {
      systemd.services.velocity = {
        description = "Velocity Proxy Server";
        wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          ExecStart = "${startScript}";
          ExecStop = "${stopScript} $MAINPID";
          Restart = "on-failure";
          User = "minecraft";
          Type = "forking";
          GuessMainPID = true;
          WorkingDirectory = "${cfg.datadir}";
        };

        preStart =
          let
            secretFile = cfg.config.forwarding-secret-file;
          in
          ''
            if [[ ! -e "${secretFile}" ]]; then
              ${getExe pkgs.openssl} rand -out ${secretFile} -base64 12
            fi

            if [[ -L "velocity.toml" ]]; then
              unlink "velocity.toml"
            elif [[ -e "velocity.toml" ]]; then
              echo "velocity.toml already exists, moving"
              mv "velocity.toml" "velocity.toml.bak"
            fi
            mkdir -p "$(dirname "velocity.toml")"
            ln -sf "${configFile}" "velocity.toml"
          '';

        postStart = ''
          ${pkgs.coreutils}/bin/chmod 660 ${tmuxSock}
        '';

        postStop = ''
          unlink velocity.toml
        '';
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.datadir} 755 minecraft minecraft"
      ];

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = mkMerge [
          [ cfg.port ]
          (mkIf cfg.config.query.enabled [ cfg.query.port ])
        ];
        allowedUDPPorts = [ cfg.port ];
      };
    }
  );
}
