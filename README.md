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

This repo contains all versions of the fabric loader, in the form of `fabric-mcversion`, the same format as how vanilla servers are versioned. You can also further specify any `fabricversion` you want by using an override: `fabric-mcversion.override { loaderVersion = "fabricversion"; }`. If this isn't specified, it will use the latest version.

The `mcversion` must be `>=1.14` and the `fabricversion` must be `>=0.13.0`. The former is a limitation of Fabric, while the latter is the constraint put on the packaging lockfile to avoid exponential growth.

For convenience, `fabric` is equivalent to the latest stable Minecraft and Fabric loader versions.

```
fabric-1_18_2
fabric-22w16b
fabric-1_18_2.override { loaderVersion = "0.14.3"; } # Specific fabric loader version
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

This example takes a list of the IDs and hashes for Modrinth mods, fetches each one, and makes a folder containing those mods. (`linkFarmFromDrvs` is quite useful because it can take a list of derivations and produce a folder suitable for this purpose.)

```nix
{
  symlinks = {
    mods = pkgs.linkFarmFromDrvs "mods" [
      (builtins.fetchurl {
        name = "lithium-fabric.jar";
        url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/mc1.19.2-0.8.3/lithium-fabric-mc1.19.2-0.8.3.jar";
        sha256 = "0vw0bp4y5aw6x97n8kwm99c0hzhkbj3vfp6ixflxampacacd9fgk";
      })
      (builtins.fetchurl {
        name = "starlight.jar";
        url = "https://cdn.modrinth.com/data/H8CaAYZC/versions/1.1.1+1.19/starlight-1.1.1%2Bfabric.ae22326.jar";
        sha256 = "0hiscgm8s2na41ql9x6y5y49775dnhwq71msm8rsh9hkjj16dpgj";
      })
      (builtins.fetchurl {
        name = "ferritecore-fabric.jar";
        url = "https://cdn.modrinth.com/data/uXXizFIs/versions/5.0.0-fabric/ferritecore-5.0.0-fabric.jar";
        sha256 = "0pakzs3mx43xzf5lmcb1rdp33f7zljyb4z88z4z1mvlmzzrc43n3";
      })
      (builtins.fetchurl {
        name = "lazydfu.jar";
        url = "https://cdn.modrinth.com/data/hvFnDODi/versions/0.1.3/lazydfu-0.1.3.jar";
        sha256 = "1j3q4w974fd06q2w373wpg0mfra2wiiiwdsqvfl1kl2p7ckpffsg";
      })
      (builtins.fetchurl {
        name = "krypton.jar";
        url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/0.2.1/krypton-0.2.1.jar";
        sha256 = "16hwhfkv44v4qhpsp1jrr7s1jca76y1yw4qniwr3f081miw7agv8";
      })
    ];
}
```

A tip is that you can use `nix-prefetch-url URL` to generate the hash you need to put in. The name attribute can be set to be anything as long as it ends with `.jar`, but if you change the name you should write the command as `nix-prefetch-url URL --name NAME`.

If you want an easier alternative to this, you can look into `packwiz` and `ferium` as minecraft mod package managers. Both are currently packaged in nixpkgs, but require you to configure them outside of nix.

## Testing a server

Change `PACKAGE_NAME` to the server you want to test. For example `quilt-1_19` or `vanilla-1_18_2`.

`nix shell .#PACKAGE_NAME.passthru.tests.minecraft-server.driver -c nixos-test-driver`

Please file an issue if you do find a server which fails this test. We do not have the capacity to test every release of minecraft and its variants that we ship in this repo.

## Roadmap

### TODO: Finish documentation

This README file is incomplete, and doesn't fully describe the `services.minecraft-servers` module.
Additionally, documentation should be added for the maintenance of the `vanilla-servers`, `fabric-servers`, and `quilt-servers`.
