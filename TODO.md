# TODO

## Improve [README.md](./README.md)

- [ ] Fully describe `services.minecraft-servers`

## Comply with Flake Spec

As of currently, the flake outputs attrsets, as opposed to direct files.
These attrsets should be moved into `legacyPackages` so as to not bother the Nix CLI, and the packages brought 'raw' into `packages`.

### Problems

- The sheer number of packages can overwhelm the Nix CLI, also makes `nix flake show` and kin borderline useless, though at least functional
  - Only include a subset of packages in `packages`? Feels wrong.
- Testing building of such a large number of packages
  - Only test stable versions
