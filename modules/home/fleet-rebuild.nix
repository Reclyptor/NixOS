{ config, lib, ... }:
let
  # The fleet inventory is the only host list; a node added there is a target
  # here with no edit to this file.
  nodes = lib.concatStringsSep " " (lib.attrNames config.fleet.nodes);
in
{
  flake.modules.homeManager.base = _: {
    home.file.".local/bin/fleet-rebuild" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash

        set -euo pipefail

        FLAKE="''${HOME}/Projects/nixos"
        NODES=(${nodes})
        WORKSTATION="nixos"
        ACTION="switch"
        ASK_PASSWORD=""

        usage() {
          echo "Usage: fleet-rebuild [-a ACTION] [-S] [HOST...]"
          echo ""
          echo "Rebuilds NixOS hosts from ''${FLAKE}. Each cluster node builds and"
          echo "activates its own configuration; this machine only evaluates it."
          echo ""
          echo "  no HOST     every cluster node, in parallel: ''${NODES[*]}"
          echo "  HOST...     only those; ''${WORKSTATION} is this workstation and is"
          echo "              rebuilt only when named"
          echo "  -a ACTION   switch (default), boot, test or dry-activate"
          echo "  -S          ask for the sudo password on each node and go one node"
          echo "              at a time, for nodes without passwordless sudo"
          exit "''${1:-1}"
        }

        while getopts ":a:Sh" OPT; do
          case "''${OPT}" in
            a) ACTION="''${OPTARG}" ;;
            S) ASK_PASSWORD=1 ;;
            h) usage 0 ;;
            *) usage ;;
          esac
        done
        shift $((OPTIND - 1))

        case "''${ACTION}" in
          switch | boot | test | dry-activate) ;;
          *) echo "Error: unknown action: ''${ACTION}" >&2; usage ;;
        esac

        is_node() {
          local NODE
          for NODE in "''${NODES[@]}"; do
            [[ "''${NODE}" == "''${1}" ]] && return 0
          done
          return 1
        }

        # Every name is checked before anything starts, so a typo cannot leave
        # the fleet half rebuilt.
        REMOTE=()
        LOCAL=""
        if [[ $# -eq 0 ]]; then
          REMOTE=("''${NODES[@]}")
        else
          for HOST in "$@"; do
            if [[ "''${HOST}" == "''${WORKSTATION}" ]]; then
              LOCAL=1
            elif is_node "''${HOST}"; then
              [[ " ''${REMOTE[*]} " == *" ''${HOST} "* ]] || REMOTE+=("''${HOST}")
            else
              echo "Error: unknown host: ''${HOST}" >&2
              echo "Known hosts: ''${NODES[*]} ''${WORKSTATION}" >&2
              exit 1
            fi
          done
        fi

        COMMIT=$(git -C "''${FLAKE}" rev-parse --short HEAD)
        echo "Deploying ''${FLAKE} at ''${COMMIT} (''${ACTION})"
        if [[ -n "$(git -C "''${FLAKE}" status --porcelain)" ]]; then
          echo "Warning: the checkout has uncommitted changes, and they are part of this deploy." >&2
        fi

        LOG_DIR="''${XDG_STATE_HOME:-''${HOME}/.local/state}/fleet-rebuild/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "''${LOG_DIR}"
        SOCKETS=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/fleet-rebuild.XXXXXX")
        CONNECTED=()

        cleanup() {
          local HOST
          for HOST in "''${CONNECTED[@]}"; do
            ssh -o ControlPath="''${SOCKETS}/%n" -O exit "''${HOST}" 2>/dev/null || true
          done
          rm -rf "''${SOCKETS}"
        }
        trap cleanup EXIT

        declare -A RESULT=()

        # One master connection per node, opened one after another, so every
        # YubiKey touch happens here in a known order and not from five builds
        # asking at once. nixos-rebuild places NIX_SSHOPTS ahead of its own
        # control-path options and ssh keeps the first value it is given, so
        # the builds ride these connections.
        for HOST in "''${REMOTE[@]}"; do
          echo "Connecting to ''${HOST} (touch the YubiKey if it blinks)"
          if ssh -o ControlMaster=yes -o ControlPath="''${SOCKETS}/%n" -o ControlPersist=no -fN "''${HOST}"; then
            CONNECTED+=("''${HOST}")
          else
            RESULT["''${HOST}"]="failed (no SSH connection)"
          fi
        done
        export NIX_SSHOPTS="-o ControlMaster=no -o ControlPath=''${SOCKETS}/%n"

        # Output is saved whole per host and echoed with the host in front, so
        # five interleaved builds stay readable. pipefail carries the rebuild's
        # exit status through tee and sed.
        rebuild() {
          local HOST="''${1}"
          shift
          nixos-rebuild "''${ACTION}" --flake "''${FLAKE}#''${HOST}" --elevate sudo "$@" 2>&1 \
            | tee "''${LOG_DIR}/''${HOST}.log" \
            | sed -u "s/^/$(printf '%-8s' "''${HOST}") | /"
        }

        rebuild_node() {
          rebuild "''${1}" --target-host "''${1}" --build-host "''${1}" "''${@:2}"
        }

        if [[ -n "''${ASK_PASSWORD}" ]]; then
          for HOST in "''${CONNECTED[@]}"; do
            if rebuild_node "''${HOST}" --ask-elevate-password; then
              RESULT["''${HOST}"]="ok"
            else
              RESULT["''${HOST}"]="failed"
            fi
          done
        else
          declare -A PID=()
          for HOST in "''${CONNECTED[@]}"; do
            rebuild_node "''${HOST}" </dev/null &
            PID["''${HOST}"]=$!
          done
          for HOST in "''${CONNECTED[@]}"; do
            if wait "''${PID[''${HOST}]}"; then
              RESULT["''${HOST}"]="ok"
            else
              RESULT["''${HOST}"]="failed"
            fi
          done
        fi

        # Last and in the foreground: a workstation switch can restart user
        # services, and sudo asks for its password on this terminal.
        if [[ -n "''${LOCAL}" ]]; then
          if rebuild "''${WORKSTATION}"; then
            RESULT["''${WORKSTATION}"]="ok"
          else
            RESULT["''${WORKSTATION}"]="failed"
          fi
        fi

        echo ""
        echo "Summary (logs in ''${LOG_DIR})"
        STATUS=0
        for HOST in "''${REMOTE[@]}" ''${LOCAL:+"''${WORKSTATION}"}; do
          printf '  %-8s %s\n' "''${HOST}" "''${RESULT[''${HOST}]}"
          [[ "''${RESULT[''${HOST}]}" == "ok" ]] || STATUS=1
        done
        exit "''${STATUS}"
      '';
    };
  };
}
