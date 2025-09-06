{
  pkgs,
  lib,
  name,
  cfg,
}:
let
  conf = cfg.servers.${name};

  inherit (lib)
    concatStringsSep
    filterAttrs
    getExe
    head
    isStringLike
    mapAttrs
    mapAttrsToList
    mkIf
    ;

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

  msConfig = conf.managementSystem._config name conf;

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
    EnvironmentFile = mkIf (cfg.environmentFile != null) (toString cfg.environmentFile);

    # Default directory for management sockets
    RuntimeDirectory = "minecraft";
    RuntimeDirectoryPreserve = "yes";
  } // msConfig.serviceConfig;

  path = conf.path;

  environment = conf.environment // msConfig.environment or { };
}
