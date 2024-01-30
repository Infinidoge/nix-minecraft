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
  - `fetchPackwizModpack`

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## Deprecation Policy

When something gets deprecated, an announcement gets added to the [changelog file](./CHANGELOG.md), and the respective parts in Nix get marked with an evaluation warning.
Deprecated code is subject to removal after 1 month.

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

All of these are found under `legacyPackages`, since they are not derivations (i.e. an attrset of derivation, or a function that returns a derivation).

### `vanillaServers.*`

[Source](./pkgs/vanilla-servers)

An attrset of all of the vanilla server versions, in the form of `vanilla-version`, where `version` is the Minecraft version (`1.18`, `1.12.2`, `22w16b`, etc), with all periods and spaces replaced with underscores (`1_18`, `1_12_2`, etc).

For convenience, `vanillaServers.vanilla` is equivalent to the latest major version.

```
vanillaServers.vanilla-1_18_2
vanillaServers.vanilla-22w16b
vanillaServers.vanilla-22w13oneblockatatime
```

### `fabricServers.*`

[Source](./pkgs/fabric-servers)

An attrset of all of the Fabric server versions, in the form of `fabric-mcversion`, following the same format as described above for version numbers. The `mcversion` must be `>=1.14`. The Fabric version is the latest released version.

To change the Fabric version, you can override the derivation and set `loaderVersion`: `fabric-mcversion.override { loaderVersion = "fabricversion"; }`.  The `loaderVersion` must be `>=0.10.7`.

For convenience, `fabricServers.fabric` is equivalent to the latest major Minecraft and Fabric versions.

```
fabricServers.fabric-1_18_2
fabricServers.fabric-22w16b
fabricServers.fabric-1_18_2.override { loaderVersion = "0.14.20"; } # Specific fabric loader version
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

If you plan on running paper without internet, you'll have to link the vanilla jar to `cache/mojang_{version}.jar`. The relevant jar is available at the package's `vanillaJar` attribute.

### `velocityServers.*`

[Source](./pkgs/velocity-servers)

An attrset of all of the Velocity server versions (differently from the others, the version does not include nor depend on specific minecraft versions).

For convenience, `velocityServers.velocity` is equivalent to the latest version.

### `minecraftServers.*`

`vanillaServers // fabricServers // quiltServers // legacyFabricServers // paperServers`. Will be used most often as it contains all of the different server versions across each mod loader. When using the overlay, this will replace the Nixpkgs `minecraftServers`.

### `fetchPackwizModpack`

[Source](./pkgs/tools/fetchPackwizModpack)

This function allows you to easily package a [packwiz](https://packwiz.infra.link/) modpack, for example, to run it own your server. An example:

```nix
let
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/Misterio77/Modpack/raw/0.2.9/pack.toml";
    packHash = "sha256-L5RiSktqtSQBDecVfGj1iDaXV+E90zrNEcf4jtsg+wk=";
  };
in
{
  services.minecraft-servers.servers.cool-modpack = {
    enable = true;
    package = pkgs.fabricServers.fabric-1_18_2.override { loaderVersion = "0.14.9"; };
    symlinks = {
      "mods" = "${modpack}/mods";
    };
  };
}
```

This will symlink the modpack's final `mods` directory into the server's `mods` directory. You can also do this for `config`, or any files in the modpack you're interested in, in a granular way.

**Note**: Be sure to use a stable URL (e.g. a git tag/commit) to the manifest, as it changing will cause the derivation to generate a different hash, breaking the build until you change it.

The built modpack also exports a `manifest` attribute, that allows you to get any information from its `pack.toml` file, such as the MC or Modloader version. You can, this way, always sync the server's version with the one the modpack recommends:

```nix
let
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/Misterio77/Modpack/raw/0.2.9/pack.toml";
    packHash = "sha256-L5RiSktqtSQBDecVfGj1iDaXV+E90zrNEcf4jtsg+wk=";
  };
  mcVersion = modpack.manifest.versions.minecraft;
  fabricVersion = modpack.manifest.versions.fabric;
  serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";
in
{
  services.minecraft-servers.servers.cool-modpack = {
    enable = true;
    package = pkgs.fabricServers.${serverVersion}.override { loaderVersion = fabricVersion; };
    symlinks = {
      "mods" = "${modpack}/mods";
    };
  };
}
```

**Note**: Using `manifest`, by default, will cause [IFD](https://nixos.wiki/wiki/Import_From_Derivation). If you want to avoid IFD while still having access to `manifest`, simply pass a `manifestHash` to the `fetchPackwizModpack` function, it will then fetch the manifest through `builtins.fetchurl`.

Additionally, you can override/add files (e.g. server-specific mods) on the pack through `addFiles`. For example:

```nix
let
  modpack = (pkgs.fetchPackwizModpack {
    url = "https://github.com/Misterio77/Modpack/raw/0.2.9/pack.toml";
    packHash = "sha256-L5RiSktqtSQBDecVfGj1iDaXV+E90zrNEcf4jtsg+wk=";
  }).addFiles {
    "mods/FabricProxy-lite.jar" = pkgs.fetchurl rec {
      pname = "FabricProxy-Lite";
      version = "1.1.6";
      url = "https://cdn.modrinth.com/data/8dI2tmqs/versions/v${version}/${pname}-${version}.jar";
      hash = "sha256-U+nXvILXlYdx0vgomVDkKxj0dGCtw60qW22EK4FhAJk=";
    };
  };
in
```

### Others

All of these packages are also available under `packages`, not just `legacyPackages`.

- `vanilla-server`: Same as `vanillaServers.vanilla`
- `fabric-server`: Same as `fabricServers.fabric`
- `quilt-server`: Same as `quiltServers.quilt`
- `paper-server`: Same as `paperServers.paper`
- `velocity-server`: Same as `velocityServers.velocity`
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

Module for hosting multiple servers at once. All of the following are under this module.


#### `enable`

If enabled, the servers in `services.minecraft-servers.servers` will be created and started as applicable. The data for the servers will be loaded from and saved to `dataDir`

#### `eula`

Whether you agree to [Mojang's EULA](https://account.mojang.com/documents/minecraft_eula) This option must be set to true to run Minecraft server.

#### `openFirewall`

Whether to open ports in the firewall for each server. Sets the default for `servers.<name>.openFirewall`. This will only work if the ports are specified in `servers.<name>.serverProperties` otherwise it will simply use the default ports. Remember to change the ports if you running multiple servers. 

#### `dataDir`

Directory to store the Minecraft servers. Each server will be under a subdirectory named after the server name in this directory, such as /srv/minecraft/servername

#### `runDir`

Directory to place the runtime tmux sockets into.
Each server's console will be a tmux socket file in the form of servername.sock. To connect to the console, run `tmux -S /run/minecraft/servername.sock attach`, press `Ctrl + b` then `d` to detach.

#### `user`

Name of the user to create and run servers under. It is recommended to leave this as the default, as it is the same user as services.minecraft-server.

#### `group`

Name of the group to create and run servers under. In order to modify the server files or attach to the tmux socket, your user must be a part of this group. It is recommended to leave this as the default, as it is the same group as services.minecraft-server

#### `environmentFile`

File consisting of lines in the form varname=value to define environment variables for the minecraft servers. Secrets (database passwords, secret keys, etc.) can be provided to server files without adding them to the Nix store by defining them in the environment file and referring to them in option `servers.<name>.files` with the syntax @varname@.

### `servers.<name>`

This family of options govern individual servers, which will be created on boot.

#### `servers.<name>.enable`

Whether to enable this server. If set to false, does NOT delete any data in the data directory, just does not generate the service file.

#### `servers.<name>.autoStart`

Whether to start this server on boot. If set to false, can still be started with systemctl start minecraft-server-servername. Requires the server to be enabled.

#### `servers.<name>.openFirewall`

Whether to open ports in the firewall for this server.

#### `servers.<name>.restart`

Value of systemd's Restart= service configuration option. Due to the servers being started in tmux sockets, values other than "no" and "always" may not work properly. As a consequence of the "always" option, stopping the server in-game with the /stop command will cause the server to automatically restart

#### `servers.<name>.enableReload`

Reload server when configuration changes (instead of restart). This action re-links/copies the declared symlinks/files. You can include additional actions (even in-game commands) by setting `<name>`.extraReload.

#### `servers.<name>.extraReload`

Extra commands to run when reloading the service. Only has an effect if `<name>.enableReload` is true.

#### `servers.<name>.whitelist`

Whitelisted players, only has an effect when enabled via `<name>.serverProperties` by setting white-list to true. Example: 
```
{
  username1 = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
  username2 = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy";
}
```

#### `servers.<name>.serverProperties`
Minecraft server properties for the server.properties file of this server. See [The Documentation](https://minecraft.wiki/w/Server.properties) on these values. Example:
```
{
  server-port = 43000;
  difficulty = 3;
  gamemode = 1;
  max-players = 5;
  motd = "NixOS Minecraft server!";
  white-list = true;
  enable-rcon = true;
  "rcon.password" = "hunter2";
}
```

#### `servers.<name>.package`
The Minecraft server package to use. Example:
`pkgs.minecraftServers.vanilla-1_18_2`

#### `servers.<name>.package`
JVM Options for this server, usually used to set ram amount. Example:
`-Xms6144M -Xmx8192M`

#### `servers.<name>.symlinks`

This option is special in that it allows for declarative management of arbitrary things inside of the server's folder. If the file is modified the existing one will have a .bak suffix added to it, if it is modified again the previous backup will be overwritten.

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
    mods = pkgs.linkFarmFromDrvs "mods" (builtins.attrValues {
      Starlight = fetchurl { url = "https://cdn.modrinth.com/data/H8CaAYZC/versions/XGIsoVGT/starlight-1.1.2%2Bfabric.dbc156f.jar"; sha512 = "6b0e363fc2d6cd2f73b466ab9ba4f16582bb079b8449b7f3ed6e11aa365734af66a9735a7203cf90f8bc9b24e7ce6409eb04d20f84e04c7c6b8e34f4cc8578bb"; };
      Lithium = fetchurl { url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/ZSNsJrPI/lithium-fabric-mc1.20.1-0.11.2.jar"; sha512 = "d1b5c90ba8b4879814df7fbf6e67412febbb2870e8131858c211130e9b5546e86b213b768b912fc7a2efa37831ad91caf28d6d71ba972274618ffd59937e5d0d"; };
      FerriteCore = fetchurl { url = "https://cdn.modrinth.com/data/uXXizFIs/versions/ULSumfl4/ferritecore-6.0.0-forge.jar"; sha512 = "e78ddd02cca0a4553eb135dbb3ec6cbc59200dd23febf3491d112c47a0b7e9fe2b97f97a3d43bb44d69f1a10aad01143dcd84dc575dfa5a9eaa315a3ec182b37"; };
      Krypton = fetchurl { url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/jiDwS0W1/krypton-0.2.3.jar"; sha512 = "92b73a70737cfc1daebca211bd1525de7684b554be392714ee29cbd558f2a27a8bdda22accbe9176d6e531d74f9bf77798c28c3e8559c970f607422b6038bc9e"; };
      LazyDFU = fetchurl { url = "https://cdn.modrinth.com/data/hvFnDODi/versions/0.1.3/lazydfu-0.1.3.jar"; sha512 = "dc3766352c645f6da92b13000dffa80584ee58093c925c2154eb3c125a2b2f9a3af298202e2658b039c6ee41e81ca9a2e9d4b942561f7085239dd4421e0cce0a"; };
      C2ME = fetchurl { url = "https://cdn.modrinth.com/data/VSNURh3q/versions/t4juSkze/c2me-fabric-mc1.20.1-0.2.0%2Balpha.10.91.jar"; sha512 = "562c87a50f380c6cd7312f90b957f369625b3cf5f948e7bee286cd8075694a7206af4d0c8447879daa7a3bfe217c5092a7847247f0098cb1f5417e41c678f0c1"; };
    });
  };
}
```

#### `servers.<name>.files`
Things to copy into this server's data directory. Similar to symlinks, but these are actual files. Useful for configuration files that don't behave well when read-only.
