{ lib }:
lib.makeExtensible (self:
with lib;
rec {
  latestVersion = versions:
    last
      (sort versionOlder
        (filter
          (v: isList (builtins.match "([[:digit:]]+\.[[:digit:]]+(\.[[:digit:]]+)?)" v))
          (attrNames versions)));

  escapeVersion = builtins.replaceStrings [ "." " " ] [ "_" "_" ];

  removeVanillaPrefix = n: escapeVersion (lib.removePrefix "vanilla-" n);
})
