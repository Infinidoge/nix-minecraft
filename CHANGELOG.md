# CHANGELOG

Documentation of major changes, newest first.

## 2023-04-05: Deprecation of `packages` flake output
Since the packages are currently wrapped inside of attrsets, the flake is more or less "broken". According to the specs, the `packages` outputs may only contain derivations, no sets.
Nixpkgs doesn't follow that structure either, that's why it uses the `legacyPackages` output instead. Doing the same thing with this flake "un-breaks" things like `nix flake show`

## 2023-02-27: Deprecation of `fetchModrinthMod` and `nix-prefetch-modrinth`

`fetchModrinthMod` and `nix-prefetch-modrinth` have been kinda just... bad from the beginning.
The ergonomics were good, however in terms of nix evaluation, it was highly inefficient, requiring extra fetches to the Modrinth API before ending up doing nothing since the file was already there.

In order to fill the gap, I've added a new tool titled `nix-modrinth-prefetch` (in order to make it name-distinct from `nix-prefetch-modrinth` while it is deprecated).
`nix-modrinth-prefetch` takes in a version ID from Modrinth and outputs the `fetchurl` invocation required to download the primary file.
