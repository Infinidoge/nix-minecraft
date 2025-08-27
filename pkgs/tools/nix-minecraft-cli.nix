{
  lib,
  writeShellApplication,
  systemd,
  tmux,
  findutils,
  coreutils,
  gnugrep,
  gawk,
  procps,
  ...
}:
writeShellApplication {
  name = "nix-minecraft-cli";

  runtimeInputs = [
    systemd
    tmux
    findutils
    coreutils
    gnugrep
    gawk
    procps
  ];

  text = ''
    set -euo pipefail

    # Default paths
    DATA_DIR="/srv/minecraft"
    RUN_DIR="/run/minecraft"

    show_help() {
      cat << 'EOF'
    nix-minecraft-cli - Manage Minecraft servers created by nix-minecraft

    Usage:
      nix-minecraft-cli list                      # list available instances with their status
      nix-minecraft-cli status <instance>         # show status of the instance
      nix-minecraft-cli send <instance> <command> # send command to the tmux session
      nix-minecraft-cli tail <instance> [-f]      # tail logs, with optional follow flag
      nix-minecraft-cli stop <instance>           # pause the instance
      nix-minecraft-cli start <instance>          # start the paused instance
      nix-minecraft-cli restart <instance>        # restart it

    Examples:
      nix-minecraft-cli list
      nix-minecraft-cli status myserver
      nix-minecraft-cli send myserver "say Hello world"
      nix-minecraft-cli tail myserver -f
      nix-minecraft-cli stop myserver
      nix-minecraft-cli start myserver
      nix-minecraft-cli restart myserver
    EOF
    }

    get_service_name() {
      local instance="$1"
      echo "minecraft-server-$instance"
    }

    get_tmux_socket() {
      local instance="$1"
      echo "$RUN_DIR/$instance.sock"
    }

    get_log_path() {
      local instance="$1"
      # Use journalctl for systemd logs
      echo "journalctl"
    }

    list_instances() {
      echo "Instance                Status"
      echo "------------------------"

      # Find all minecraft server data directories
      if [[ -d "$DATA_DIR" ]]; then
        for server_dir in "$DATA_DIR"/*; do
          if [[ -d "$server_dir" ]]; then
            instance=$(basename "$server_dir")
            service_name=$(get_service_name "$instance")

            # Check if service exists and get status
            if systemctl list-unit-files --type=service | grep -q "^$service_name.service"; then
              if systemctl is-active --quiet "$service_name"; then
                status="running"
              elif systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
                status="stopped"
              else
                status="disabled"
              fi
            else
              status="no-service"
            fi

            printf "%-24s %s\n" "$instance" "$status"
          fi
        done
      else
        echo "No Minecraft data directory found at $DATA_DIR"
      fi
    }

    show_status() {
      local instance="$1"
      local service_name
      service_name=$(get_service_name "$instance")

      echo "Instance: $instance"
      echo "Service: $service_name"
      echo

      # Show systemd status
      systemctl status "$service_name" --no-pager -l || true

      echo
      echo "Recent logs:"
      journalctl -u "$service_name" -n 10 --no-pager || true
    }

    send_command() {
      local instance="$1"
      local command="$2"
      local socket
      socket=$(get_tmux_socket "$instance")

      if [[ ! -S "$socket" ]]; then
        echo "Error: tmux socket not found at $socket"
        echo "Make sure the server is running and using tmux management"
        exit 1
      fi

      # Send command to tmux session
      tmux -S "$socket" send-keys "$command" Enter
      echo "Command sent: $command"
    }

    tail_logs() {
      local instance="$1"
      local follow_flag=""

      # Check if -f flag is provided
      if [[ $# -gt 1 && "$2" == "-f" ]]; then
        follow_flag="-f"
      fi

      local service_name
      service_name=$(get_service_name "$instance")

      # Use journalctl to tail logs
      if [[ "$follow_flag" == "-f" ]]; then
        journalctl -u "$service_name" -f --no-pager
      else
        journalctl -u "$service_name" -n 50 --no-pager
      fi
    }

    stop_instance() {
      local instance="$1"
      local service_name
      service_name=$(get_service_name "$instance")

      echo "Stopping $instance..."
      systemctl stop "$service_name"
      echo "Stopped $instance"
    }

    start_instance() {
      local instance="$1"
      local service_name
      service_name=$(get_service_name "$instance")

      echo "Starting $instance..."
      systemctl start "$service_name"
      echo "Started $instance"
    }

    restart_instance() {
      local instance="$1"
      local service_name
      service_name=$(get_service_name "$instance")

      echo "Restarting $instance..."
      systemctl restart "$service_name"
      echo "Restarted $instance"
    }

    # Main command processing
    if [[ $# -eq 0 ]]; then
      show_help
      exit 1
    fi

    case "$1" in
      list)
        list_instances
        ;;
      status)
        if [[ $# -lt 2 ]]; then
          echo "Error: instance name required"
          echo "Usage: nix-minecraft-cli status <instance>"
          exit 1
        fi
        show_status "$2"
        ;;
      send)
        if [[ $# -lt 3 ]]; then
          echo "Error: instance name and command required"
          echo "Usage: nix-minecraft-cli send <instance> <command>"
          exit 1
        fi
        # Join all arguments after the second as the command
        instance="$2"
        shift 2
        command="$*"
        send_command "$instance" "$command"
        ;;
      tail)
        if [[ $# -lt 2 ]]; then
          echo "Error: instance name required"
          echo "Usage: nix-minecraft-cli tail <instance> [-f]"
          exit 1
        fi
        tail_logs "$2" "''${3:-}"
        ;;
      stop)
        if [[ $# -lt 2 ]]; then
          echo "Error: instance name required"
          echo "Usage: nix-minecraft-cli stop <instance>"
          exit 1
        fi
        stop_instance "$2"
        ;;
      start)
        if [[ $# -lt 2 ]]; then
          echo "Error: instance name required"
          echo "Usage: nix-minecraft-cli start <instance>"
          exit 1
        fi
        start_instance "$2"
        ;;
      restart)
        if [[ $# -lt 2 ]]; then
          echo "Error: instance name required"
          echo "Usage: nix-minecraft-cli restart <instance>"
          exit 1
        fi
        restart_instance "$2"
        ;;
      help|--help|-h)
        show_help
        ;;
      *)
        echo "Error: unknown command '$1'"
        echo
        show_help
        exit 1
        ;;
    esac
  '';
}
