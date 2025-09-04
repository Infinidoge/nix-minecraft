#!/usr/bin/env bash

set -euo pipefail

printerr() {
  echo -n "[Error] " >&2
  echo "$@" >&2
}
erroras() {
  printerr "$@"
  exit 1
}
printwarn() {
  echo -n "[Warning] " >&2
  echo "$@" >&2
}

if [ "${NIX_MINECRAFT_MINECRAFTCTL_FILE:-"not-found"}" == "not-found" ]; then
  printwarn "Environment variable NIX_MINECRAFT_MINECRAFTCTL_FILE is not found. Maybe you haven't installed nix-minecraft on this machine?"
elif [ ! -f "${NIX_MINECRAFT_MINECRAFTCTL_FILE}" ]; then
  printwarn "Environment variable NIX_MINECRAFT_MINECRAFTCTL_FILE exists but file is not there."
elif [ "$(cat "$NIX_MINECRAFT_MINECRAFTCTL_FILE")" == "{}" ]; then
  printwarn "Environment variable NIX_MINECRAFT_MINECRAFTCTL_FILE exists but the content is empty. Maybe you have no servers configured?"
fi

is_integer() {
  local str="$1"
  if ! [[ "$str" =~ ^[0-9]+$ ]]; then
    erroras "\"$1\" is not an integer."
  fi
}

help() {
  echo "
minecraftctl: A minecraft instance controller for nix-minecraft

Usage: minecraftctl <command>

Commands:
  help                       show help
  list                       list available minecraft instances
  status <instance>          show status of the instance
  tail <instance>            tail the log of the instance
  send <instance> <command>  send command to the instance
  start <instance>           start the server
  stop <instance>            stop the server
  restart <instance>         restart the server
"
}

# example usage: query my-server .type # -> vanilla
# example usage: query my-server # -> {"type":"vanilla", ...}
query() {
  local instance="$1"
  local q="${2:-.}"
  local serverConfig
  serverConfig=$(jq ".\"$instance\"" "$NIX_MINECRAFT_MINECRAFTCTL_FILE")
  if [ "$serverConfig" == "null" ]; then
    erroras "query: Instance \"$instance\" not found. see minecraftctl list for available instances."
  fi
  result=$(echo "$serverConfig" | jq -r "$q")
  if [ "$result" == "null" ]; then
    erroras "query: Instance was found, but it does not contain query \"$q\""
  fi
  echo "$result"
}
getService() {
  query "$1" .serviceName
}

status() {
  local output loadError instance
  instance="$(getService "$1")"
  output="$(systemctl show --property=ActiveState,LoadError "$instance" | jc --ini)"
  loadError="$(echo "$output" | jq -r ".LoadError")"
  if [ "$loadError" != "" ]; then
    if [[ "$loadError" =~ ^org\.freedesktop\.systemd1\.NoSuchUnit ]]; then
      echo "Unit not found"
    else
      echo "$loadError"
    fi
    exit
  fi
  echo "$output" | jq -r ".ActiveState"
}
send() {
  local instance command type
  instance="$1"
  shift
  command="$*"

  type="$(query "$instance" .managementSystem.type)"
  case "$type" in
    tmux)
      socket="$(query "$instance" .managementSystem.tmux.socketPath)"
      tmux -S "$socket" send-keys "$command" Enter
      ;;
    systemd-socket)
      socket="$(query "$instance" .managementSystem.systemdSocket.stdinSocket.path)"
      if [ ! -S "$socket" ]; then
        erroras "Systemd socket does not exist at $socket"
      fi
      # echo automatically inserts newline
      echo "$command" | socat - UNIX-CONNECT:"$socket"
      ;;
    *)
      erroras "Internal Error: management system type is unknown: ${type}"
      ;;
  esac
}

cmd_tail() {
  local args=()
  local tail_flags=()

  while (( $# )); do
    case "$1" in
      -f|--follow)
        tail_flags+=("-f")
        ;;
      -F)
        tail_flags+=("-F")
        ;;
      --retry)
        tail_flags+=("--retry")
        ;;
      -n|--lines)
        if [ "${2:0:1}" != "-" ]; then
          is_integer "$2"
          local lines="$2"
          tail_flags+=("-n" "$lines")
          shift
        else
          erroras "tail: Argument for $1 is missing"
        fi
        ;;
      -*)
        erroras "tail: Unknown flag: $1."
        ;;
      *)
        args+=("$1")
    esac
    shift
  done

  args_len="${#args[@]}"
  if [ "$args_len" -gt 1 ]; then
    erroras "tail: Too many arguments - expected 1, got $args_len"
  elif [ "$args_len" -lt 1 ]; then
    erroras "tail: Not enough arguments - expected 1, got $args_len."
  fi

  local instance="${args[0]}"
  local file
  file="$(query "$instance" ".dataDir")/logs/latest.log"
  tail "$file" "${tail_flags[@]}"
}

cmd_list() {
  local output=$'NAME\tVERSION\tLOADER\tPORT\tSTATUS\n'
  for instance in $(jq -r 'keys[]' "$NIX_MINECRAFT_MINECRAFTCTL_FILE"); do
    output+="$(query "$instance" '[.name, .minecraftVersion, .type, .port] | @tsv')"
    output+=$'\t'
    output+="$(status "$instance")"
    output+=$'\n'
  done

  echo "$output" | column -t -s $'\t'
}

cmd_status() {
  systemctl status "$(getService "$1")"
}
cmd_start() {
  systemctl start "$(getService "$1")"
}
cmd_stop() {
  systemctl stop "$(getService "$1")"
}
cmd_restart() {
  systemctl restart "$(getService "$1")"
}

# A helper script to fetch UUID of a player
cmd_uuid() {
  local query resp error name uuid
  query="${1:?Usage: minecraftctl uuid <player>}"
  resp="$(curl -s "https://api.mojang.com/users/profiles/minecraft/$query")"
  
  error="$(echo "$resp" | jq -r '.errorMessage')"
  if [ "$error" != null ]; then
    erroras "$error"
  fi

  name="$(echo "$resp" | jq -r '.name')"
  uuid="$(echo "$resp" | jq -r '.id | (.[:8] + "-" + .[8:12] + "-" + .[12:16] + "-" + .[16:20] + "-" + .[20:])')"
  
  echo uuid for "$name" is "$uuid"
}

case "${1:-help}" in
  help|--help)
    help
    ;;
  list)
    cmd_list "$@"
    ;;
  send)
    shift
    send "$@"
    ;;
  tail)
    shift
    cmd_tail "$@"
    ;;
  status)
    shift
    cmd_status "$@"
    ;;
  start)
    shift
    cmd_start "$@"
    ;;
  stop)
    shift
    cmd_stop "$@"
    ;;
  restart)
    shift
    cmd_restart "$@"
    ;;

  # utility scripts
  uuid)
    shift
    cmd_uuid "$@"
    ;;

  # debugging
  query)
    shift
    query "$@"
    ;;
  *)
    erroras "Unknown subcommand: $1"
    ;;
esac
