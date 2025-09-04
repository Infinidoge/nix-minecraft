# Minecraftctl

`minecraftctl` is a CLI tool that wraps systemctl and socket interactions for easier use.

## Commands

```sh
minecraftctl list # list available instances with their status

# socket interaction
minecraftctl send <instance> <command> # send command to the tmux/systemd socket
minecraftctl tail <instance> [-f] [-n <number>] # tail logs, with optional follow flag [-f] and length [-n <number>]

# systemd management
minecraftctl status <instance> # show status of the instance
minecraftctl start <instance> # start the paused instance
minecraftctl stop <instance> # pause the instance
minecraftctl restart <instance> # restart the instance
```
