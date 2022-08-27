# nix-minecraft

## About

`nix-minecraft` is an attempt to better package and support Minecraft as part of the Nix ecosystem. As of currently, it packages all versions of minecraft vanilla, along with all supported versions of the Fabric and Quilt loaders.

## Installation

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
  # For the service module
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];

  # For the package overlay, laid out as: `pkgs.nix-minecraft.PACKAGE`
  nixpkgs.overlays = [ inputs.nix-minecraft.overlays.default ];
}
```

From there, you can setup the service or use the packages, as described below.

There is also possibility of using this repo in a non-flake thanks to `flake-compat` using its outputs for `packages.<system>.PACKAGE`, `nixosModules.nix-minecraft`, and similar.

## Packages

### Vanilla servers
[Source](./pkgs/minecraft-servers)

This repo contains all of the vanilla server versions, in the form of `vanilla-version`, where `version` is the Minecraft version (`1.18`, `1.12.2`, `22w16b`, etc), with all periods and spaces replaced with underscores (`1_18`, `1_12_2`, etc).

For convenience, `vanilla` is equivalent to the latest stable version.

```
vanilla-1_18_2
vanilla-22w16b
vanilla-22w13oneblockatatime
```

Or through the overlay:
```
pkgs.nix-minecraft.vanilla-1_18_2
```


### Fabric servers
[Source](./pkgs/fabric-servers)

This repo contains all versions of the fabric loader, in the form of `fabric-mcversion` and `fabric-mcversion-fabricversion`, following the same format as vanilla servers for its version numbers. If the `fabricversion` isn't specified, it will use the latest version.

The `mcversion` must be `>=1.14`, and if specified, the `fabricversion` must be `>=0.10.7`. The former is a limitation of Fabric, while the latter is the constraint put on the packaging lockfile to avoid exponential growth.

For convenience, `fabric` is equivalent to the latest stable Minecraft and Fabric loader versions.

```
fabric-1_18_2
fabric-22w16b
fabric-1_18_2-0_13_3 # Specific fabric loader version
```

Or through the overlay:
```
pkgs.nix-minecraft.fabric-1_18_2
```

### Quilt servers
[Source](./pkgs/quilt-servers)

Quilt servers function the same as fabric servers, but with the Quilt mod loader.

```
quilt-1_19
```

Or though the overlay:
```
pkgs.nix-minecraft.quilt-1_19
```

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

## Roadmap

### TODO: Finish documentation

This README file is incomplete, and doesn't fully describe the `services.minecraft-servers` module.
Additionally, documentation should be added for the maintenance of the `vanilla-servers`, `fabric-servers`, and `quilt-servers`.
