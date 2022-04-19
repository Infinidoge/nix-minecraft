{ lib }:
lib.makeExtensible (self:
  with lib;
  with builtins;
  rec {
    latestVersion = versions:
      last
        (sort versionOlder
          (filter
            (v: isList (match "([[:digit:]]+\.[[:digit:]]+(\.[[:digit:]]+)?)" v))
            (attrNames versions)));

    escapeVersion = builtins.replaceStrings [ "." " " ] [ "_" "_" ];
  }
)
