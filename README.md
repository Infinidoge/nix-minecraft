# nix-minecraft

## About

`nix-minecraft` is an attempt to better package and support Minecraft as part of the Nix ecosystem.
As of currently, it packages:

- All versions of Vanilla
- All supported versions of the following mod/plugin loaders/servers:
  - Fabric
  - Legacy Fabric
  - Quilt
  - Paper
- All supported versions of the following:
  - Velocity proxy
- Various tools
  - `nix-modrinth-prefetch`

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## Installation

This repository is made exclusively as a Nix flake. Due to a lack of understanding of now Nix flake compat works, I have not included it, however if a PR is made to add compatibility, I may accept it.

In your `flake.nix`:

```nix
{
  inputs = {
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };
}
```

In your system configuration:

```nix
{ inputs, ... }: # Make sure the flake inputs are in your system's config
{
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
}
```

From there, you can setup the service or use the packages, as described below.

## Roadmap

See [TODO.md](./TODO.md).

## Packages

### `vanillaServers.*`

[Source](./pkgs/minecraft-servers)

An attrset of all of the vanilla server versions, in the form of `vanilla-version`, where `version` is the Minecraft version (`1.18`, `1.12.2`, `22w16b`, etc), with all periods and spaces replaced with underscores (`1_18`, `1_12_2`, etc).

For convenience, `vanillaServers.vanilla` is equivalent to the latest major version.

```
vanillaServers.vanilla-1_18_2
vanillaServers.vanilla-22w16b
vanillaServers.vanilla-22w13oneblockatatime
```

### `fabricServers.*`

[Source](./pkgs/fabric-servers)

An attrset of all of the Fabric server versions, in the form of `fabric-mcversion` or `fabric-mcversion-fabricversion`, following the same format as described above for version numbers. If the `fabricversion` isn't specified, it uses the latest version.

The `mcversion` must be `>=1.14`, and if specified, the `fabricversion` must be `>=0.10.7`. The former is a limitation of Fabric, while the latter is the constraint I put on my packaging lockfile.

For convenience, `fabricServers.fabric` is equivalent to the latest major Minecraft and Fabric versions.

```
fabricServers.fabric-1_18_2
fabricServers.fabric-22w16b
fabricServers.fabric-1_18_2-0_13_3 # Specific fabric loader version
```

### `quiltServers.*`

[Source](./pkgs/quilt-servers)

`quiltServers` functions the same as `fabricServers`, but with the Quilt mod loader.

### `legacyFabricServers.*`

[Source](./pkgs/legacy-fabric-servers)

`legacyFabricServers` functions the same as `fabricServers`, but with versions provided by the Legacy Fabric project.

Since Legacy Fabric does not have a defined newest version to target, it lacks a `legacy-fabric` attribute pointing to the latest version/loader version combination.

### `paperServers.*`

[Source](./pkgs/paper-servers)

`paperServers` functions the same as `fabricServers`, but with the Paper server software.

### `velocityServers.*`

[Source](./pkgs/velocity-servers)

An attrset of all of the Velocity server versions (differently from the others, the version does not include nor depend on specific minecraft versions).

For convenience, `velocityServers.velocity` is equivalent to the latest version.

### `minecraftServers.*`

`vanillaServers // fabricServers // quiltServers // legacyFabricServers // paperServers`. Will be used most often as it contains all of the different server versions across each mod loader. When using the overlay, this will replace the Nixpkgs `minecraftServers`.

### Others

- `vanilla-server`: Same as `vanillaServers.vanilla`
- `fabric-server`: Same as `fabricServers.fabric`
- `minecraft-server`: Same as `vanilla-server`

#### `nix-modrinth-prefetch`

[Source](./pkgs/tools/nix-modrinth-prefetch.nix)

A helper script to fetch a Modrinth mod, which outputs the necessary `fetchurl` invocation.

To use it, first find a mod on Modrinth, and click on the version you want.
In the displayed information, there is a `Version ID` string.
Click on it to copy the version ID.
Then, run the script like so:

```shell
nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- versionid
```

(This helper script can also be used in a temporary shell with `nix shell github:Infinidoge/nix-minecraft#nix-modrinth-prefetch`)

This `fetchurl` invocation directly fetches the mod, and can be copy-pasted to wherever necessary.

## Modules

### `services.minecraft-servers`

[Source](./modules/minecraft-servers.nix)

Module for hosting multiple servers at once.

TODO: Finish documentation of the module. In the meantime, see [source](./modules/minecraft-servers.nix).

### `servers.<name>`

This family of options govern individual servers, which will be created on boot.

#### `servers.<name>.symlinks`

This option is special in that it allows for declarative management of arbitrary things inside of the server's folder.

How it works is that it takes an attrset of derivations, and symlinks each derivation into place with the name of the attribute in the attrset.

For example,

```nix
{
  symlinks = {
    text-file = pkgs.writeTextFile {
      name = "text-file";
      text = "Some text";
    };
  };
}
```

Would symlink a file containing `"Some text"` into the server's folder.

This option is quite powerful, and can be used for a number of things, though most notably it can be used for declaratively setting up mods or plugins for the server.

This example takes an attrset of the IDs and hashes for Modrinth mods, fetches each one, and makes a folder containing those mods. (`linkFarmFromDrvs` is quite useful because it can take a list of derivations and produce a folder suitable for this purpose.) The names in this attrset are meaningless, I only included them as convenient labels.

```nix
{
  symlinks = {
    mods = pkgs.linkFarmFromDrvs "mods" (map pkgs.fetchModrinthMod (builtins.attrValues {
      Starlight = { id = "4ew9whL8"; hash = "00w0alwq2bnbi1grxd2c22kylv93841k8dh0d5501cl57j7p0hgb"; };
      Lithium = { id = "MoF1cn6g"; hash = "0gw75p4zri2l582zp6l92vcvpywsqafhzc5a61jcpgasjsp378v1"; };
      FerriteCore = { id = "776Z5oW9"; hash = "1gvy92q1dy6zb7335yxib4ykbqrdvfxwwb2a40vrn7gkkcafh6dh"; };
      Krypton = { id = "vJQ7plH2"; hash = "1y6sn1pjd9kl2ig73zg3zb7f6p2a36sa9f7gjzawrpnp0q6az4cf"; };
      LazyDFU = { id = "C6e265zK"; hash = "1fga62yiz8189qrl33l4p5m05ic90dda3y9bg7iji6z97p4js8mj"; };
      C2ME = { id = "5P5gJ4ws"; hash = "1xyhyy7v99k4cvxq5b47jgra481m73zx025ylps0kjlwx7b90jkh"; };
    }));
  };
}
```
