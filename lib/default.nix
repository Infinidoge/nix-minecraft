{ lib }:
lib.makeExtensible (
  self:
  let
    inherit (lib)
      attrNames
      concatLines
      concatStrings
      concatStringsSep
      drop
      filter
      filterAttrs
      hasSuffix
      id
      isList
      last
      mapAttrs'
      removePrefix
      removeSuffix
      sort
      splitString
      stringToCharacters
      take
      versionOlder
      nameValuePair
      ;
    inherit (builtins)
      match
      pathExists
      readDir
      replaceStrings
      typeOf
      ;
  in
  rec {
    chain = {
      func = id;
      __functor =
        self: input:
        if (typeOf input) == "lambda" then self // { func = e: input (self.func e); } else self.func input;
    };

    isNormalVersion = v: isList (match "([[:digit:]]+\.[[:digit:]]+(\.[[:digit:]]+)?)" v);

    latestVersion =
      versions: chain (filter isNormalVersion) (sort versionOlder) last (attrNames versions);

    escapeVersion = replaceStrings [ "." " " ] [ "_" "_" ];

    removeVanilla = n: escapeVersion (removePrefix "vanilla-" n);

    # Stolen from digga: https://github.com/divnix/digga/blob/587013b2500031b71959496764b6fdd1b2096f9a/src/importers.nix#L61-L114
    rakeLeaves =
      dirPath:
      let
        seive =
          file: type:
          # Only rake `.nix` files or directories
          (type == "regular" && hasSuffix ".nix" file) || (type == "directory");

        collect = file: type: {
          name = removeSuffix ".nix" file;
          value =
            let
              path = dirPath + "/${file}";
            in
            if (type == "regular") || (type == "directory" && pathExists (path + "/default.nix")) then
              path
            # recurse on directories that don't contain a `default.nix`
            else
              rakeLeaves path;
        };

        files = filterAttrs seive (readDir dirPath);
      in
      filterAttrs (n: v: v != { }) (mapAttrs' collect files);

    # Same as collectFiles, but only gathers files from a specific subdirectory
    # (e.g. "config")
    collectFilesAt =
      path: subdir: mapAttrs' (n: nameValuePair ("${subdir}/${n}")) (collectFiles "${path}/${subdir}");

    # Get all files from a path (e.g. a modpack derivation) and return them in the
    # format expected by the files/symlinks module options.
    collectFiles =
      let
        mapListToAttrs =
          fn: fv: list:
          lib.listToAttrs (map (x: nameValuePair (fn x) (fv x)) list);
      in
      path:
      mapListToAttrs (x: builtins.unsafeDiscardStringContext (lib.removePrefix "${path}/" x)) (lib.id) (
        lib.filesystem.listFilesRecursive "${path}"
      );

    wrapJarManifest =
      manifestText:
      let
        chunkCharacters' =
          characters: chunks:
          if
            characters != [ ] # 71 characters plus space prefix = 72 line length
          then
            chunkCharacters' (drop 71 characters) (chunks ++ [ (take 71 characters) ])
          else
            chunks;

        chunkCharacters =
          characters: # First line gets 72 due to not having space prefix
          chunkCharacters' (drop 72 characters) [ (take 72 characters) ];

        wrapLine = chain stringToCharacters chunkCharacters (map concatStrings) (concatStringsSep "\n ");
      in
      chain (splitString "\n") (map wrapLine) concatLines manifestText;

    getPackageInfo =
      package:
      let
        inherit (builtins) elemAt;
        inherit (lib) lists;
        name = lib.splitString "-" package.name;
        len = builtins.length name;
        at = idx: elemAt name idx;
        warnAndDefault =
          lib.warn "[nix-minecraft] Could not infer minecraft server type from \"${package.name}\""
            {
              type = "unknown (${package.name})";
              minecraftVersion = "?";
            };
      in
      ## == our packaging ==
      # "paper-${mcVersion}-build.${buildNumber}" # paper
      if len == 3 && (at 0 == "paper") then
        {
          type = "paper";
          minecraftVersion = at 1;
        }
      # "velocity-${velocityVersion}-build.${buildNumber}" # velocity
      else if len == 3 && (at 0 == "velocity") then
        {
          type = "velocity";
          minecraftVersion = "-"; # it doesn't make sense to define minecraft version
        }
      else
      # should have prefix "minecraft-server-${mcVersion}"
      if (len >= 3 && (lists.hasPrefix [ "minecraft" "server" ] name)) then
        # "minecraft-server-${mcVersion}"
        if len == 3 then
          {
            type = "vanilla";
            minecraftVersion = at 2;
          }
        else
        # "minecraft-server-${mcVersion}-${loader}-${loaderVersion}"
        if len == 5 then
          {
            type = at 3;
            minecraftVersion = at 2;
          }
        else
        # "minecraft-server-${mcVersion}-legacy-fabric-${loaderVersion}" # legacy fabric
        if len == 6 then
          {
            type = "legacy-fabric";
            minecraftVersion = at 2;
          }
        else
          warnAndDefault
      else
      ## == from nixpkgs ==
      # "mchprs-${mchprsVersion}" # mchprs
      if len == 2 && at 0 == "mchprs" then
        {
          type = "mchprs";
          minecraftVersion = "?"; # it does not seem to contain minecraft version info
        }
      else
      # "papermc-${mcVersion}-${buildNumber}"
      if len == 3 && at 0 == "papermc" then
        {
          type = "papermc";
          minecraftVersion = at 1;
        }
      else
      # "purpur-${mcVersion}r${buildNumber}"
      if len == 2 && at 0 == "purpur" then
        {
          type = "papermc";
          minecraftVersion = elemAt (splitString "r" (at 1)) 0;
        }
      else
      # "velocity-${velocityVersion}-unstable-${y}-${m}-${d}"
      if len == 6 && at 0 == "velocity" then
        {
          type = "velocity";
          minecraftVersion = "-"; # it doesn't make sense to define minecraft version
        }
      else
        warnAndDefault;
  }
)
