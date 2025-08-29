# Minecraftctl Specification

## Argument parsing

All the following command should result into the same tail command.

```sh
minecraftctl tail foo-instance -f -n 100
minecraftctl tail "foo-instance" -f -n 100 # ""s should not matter
minecraftctl tail -f foo-instance -n 100 # flag can go before the instance name
minecraftctl tail -n 100 -f foo-instance # order of flags should not matter (it can result in differen ordering of the internal tail command, but the behavior is the same)
minecraftctl tail foo-instance --lines 100 --follow # should allow long flags
```

## Toolkit support

- It switches its behavior depending on whether the server is managed by tmux or systemd socket.

## System Configuration

This CLI expects the following things to be set:

- env NIX_MINECRAFT_MINECRAFTCTL_FILE: Path to the file below
- file /nix/store/<hash>-minecraftctl.json: File<Record<string, MinecraftServer>>
  - Server Configuration JSON

## Data format

```ts
type MinecraftServer = {
  name: string // name of the server (example: "my-server")
  type: "vanilla" | "fabric" | "legacy fabric" | "quilt" | "paper" // mod/plugin loader of the server (or just vanilla) (TODO)
  minecraftVersion: "{number}.{number}.{number}" // version of minecraft (TODO)
  port: number // port that the instance uses (example: 25565)
  dataDir: path // path to the data dir (example: "/srv/minecraft/my-server")
  serviceName: string // systemd service name (example: "minecraft-server-my-server")
  managementSystem: ManagementSystem // socket management
}

type ManagementSystem =
  | {
      type: "tmux" // type of the socket (example: "tmux")
      tmux: {
        socketPath: path // path to the tmux socket (example: "/run/minecraft/my-server.sock")
    }
  | {
      type: "systemd-socket"
      systemdSocket: {
        stdinSocket: {
          path: path // path to the systemd stdin socket (example: "/run/minecraft/my-server.stdin")
        }
      }
    }
```
