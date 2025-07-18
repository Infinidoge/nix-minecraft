# TODO

## Documentation

### Improve [README.md](./README.md)

- [ ] Fully describe `services.minecraft-servers`

### Contributing

- Add more details for expections around certain parts of the repository

### Other

- Document how packages are built, for the sake of explanation

## Flake

### Rewrite [mkTextileServer](./pkgs/build-support/mkTextileServer.nix)

- Turn into a full-fledged derivation instead of using `writeShellScriptBin`
- Merge with [mkTextileLoader](./pkgs/build-support/mkTextileLoader.nix)?

### DRY Update Scripts

- Pull out common functions into a library, reuse in the update scripts
- Particularly noticeable in the textile update scripts, which are ~95% identical

## Misc

- [ ] Fetch Quilt server launcher main class from API
- [ ] Check requested Java version to ensure jre_headless is new enough
- [ ] Add a packwiz pack function that uses local files instead of a pack URL
- [ ] Create a new `fetchModrinthMod` using a fixed-output derivation
- [ ] Create a new `fetchCurseForgeMod` using a fixed-output derivation
