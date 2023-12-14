{ callPackage
, lib
}:
let
  inherit (builtins) listToAttrs sort filter;
  inherit (lib) nameValuePair last recurseIntoAttrs flatten mapAttrsToList versionOlder importJSON;
  inherit (lib.our) escapeVersion;
  versions = importJSON ./lock.json;

  # Sort by attribute 'attr' using 'f' function
  sortBy = attr: f: sort (a: b: f a.${attr} b.${attr});

  packages =
    mapAttrsToList
      (version: builds:
        sortBy "version" versionOlder (mapAttrsToList
          (buildNumber: value:
            callPackage ./derivation.nix {
              inherit (value) url sha256 channel;
              version = "${version}-build.${buildNumber}";
            })
          builds))
      versions;
  stablePackages = filter (x: x != [ ]) (map (filter (x: x.meta.branch != "experimental")) packages);
in
recurseIntoAttrs (listToAttrs (
  (map (x: nameValuePair (escapeVersion x.name) x) (flatten packages))
  ++ [ (nameValuePair "velocity" (last (last stablePackages))) ]
))
