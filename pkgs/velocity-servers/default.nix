{
  callPackage,
  lib,
}:
let
  inherit (lib.our)
    escapeVersion
    sortVersions
    ;
  inherit (builtins)
    listToAttrs
    filter
    ;
  inherit (lib)
    nameValuePair
    last
    recurseIntoAttrs
    flatten
    mapAttrsToList
    importJSON
    ;

  versions = importJSON ./lock.json;

  packages = mapAttrsToList (
    version: builds:
    sortVersions (
      mapAttrsToList (
        buildNumber: value:
        callPackage ./derivation.nix {
          inherit (value) url sha256 channel;
          version = "${version}-build.${buildNumber}";
        }
      ) builds
    )
  ) versions;
  stablePackages = filter (x: x != [ ]) (map (filter (x: x.meta.branch != "experimental")) packages);
in
recurseIntoAttrs (
  listToAttrs (
    (map (x: nameValuePair (escapeVersion x.name) x) (flatten packages))
    ++ [ (nameValuePair "velocity" (last (last stablePackages))) ]
  )
)
