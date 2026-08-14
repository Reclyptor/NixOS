{ config, lib, ... }:

# THE fleet inventory — one definition of who the cluster nodes are and how they
# are addressed. Before this, the same topology was written out in four
# independent places: each modules/hosts/*.nix, base.nix's networking.hosts,
# kube-api-lb.nix's HAProxy backends, and k3s.nix's etcd peer list (plus
# cilium.nix hardcoding the union of wired interface names). Adding or
# re-addressing a node meant finding all five and keeping them consistent by
# hand; anything missed fails at runtime, on the datapath, not at eval.
#
# The node schema is declared once here and reused as the type of the NixOS-level
# `host` option (modules/server/options.nix), so there is one schema as well as
# one data set. Server modules keep reading `config.host.*` exactly as before —
# each host file just points `host` at its entry below.
let
  # One optical drive. `name` defaults to bluray-<serial> so a node usually only
  # has to list serials; override it for positional names like "bluray0".
  opticalDriveType = lib.types.submodule (
    { config, ... }:
    {
      options = {
        serial = lib.mkOption {
          type = lib.types.str;
          description = "USB serial (udev ID_SERIAL_SHORT / ATTRS{serial}).";
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = "bluray-${config.serial}";
          description = "Symlink created under /dev.";
        };
        sg = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Also symlink the SCSI-generic node as <name>-sg.";
        };
      };
    }
  );

  nodeType = lib.types.submodule {
    options = {
      hostId = lib.mkOption {
        type = lib.types.str;
        description = "networking.hostId (required by ZFS).";
      };

      wiredInterface = lib.mkOption {
        type = lib.types.str;
        default = "eno1";
        description = "Wired NIC carrying the node IP / k3s traffic.";
      };

      wirelessInterface = lib.mkOption {
        type = lib.types.str;
        default = "wlp2s0";
        description = "Wireless NIC kept as the out-of-band SSH lifeline.";
      };

      wiredIp = lib.mkOption {
        type = lib.types.str;
        description = "Static LAN address of the wired NIC (the k3s node IP).";
      };

      wirelessIp = lib.mkOption {
        type = lib.types.str;
        description = "Static LAN address of the wireless NIC.";
      };

      k3s.role = lib.mkOption {
        type = lib.types.enum [
          "server"
          "agent"
        ];
        description = "k3s role: control-plane server or worker agent.";
      };

      k3s.bootstrap = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this node initialized the cluster (clusterInit); all others join via the local API load balancer.";
      };

      gpu = lib.mkOption {
        type = lib.types.enum [
          "amd"
          "nvidia"
        ];
        default = "amd";
        description = "GPU vendor; selects kernel modules, drivers, and tooling.";
      };

      opticalDrives = lib.mkOption {
        type = lib.types.listOf opticalDriveType;
        default = [ ];
        description = "Optical drives physically attached to this node. Empty for nodes with none.";
      };
    };
  };
in
{
  options.fleet = {
    nodeType = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      description = "Submodule type for one cluster node; also types the NixOS `host` option.";
    };

    opticalDriveType = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      description = "Submodule type for one optical drive; also types the NixOS `opticalDrives` option.";
    };

    nodes = lib.mkOption {
      type = lib.types.attrsOf nodeType;
      default = { };
      description = "Every cluster node, keyed by hostname.";
    };

    controlPlane = lib.mkOption {
      type = lib.types.attrsOf nodeType;
      readOnly = true;
      description = "The subset of nodes running the k3s control plane (apiserver + embedded etcd).";
    };
  };

  config.fleet = {
    inherit nodeType opticalDriveType;

    controlPlane = lib.filterAttrs (_: node: node.k3s.role == "server") config.fleet.nodes;

    nodes = {
      archeon = {
        hostId = "4ea934c3";
        wiredIp = "192.168.1.10";
        wirelessIp = "192.168.1.20";
        k3s = {
          role = "server";
          bootstrap = true;
        };
      };

      fluxeon = {
        hostId = "491bbece";
        wiredIp = "192.168.1.11";
        wirelessIp = "192.168.1.21";
        k3s.role = "server";
      };

      voideon = {
        hostId = "1364e987";
        wiredIp = "192.168.1.12";
        wirelessIp = "192.168.1.22";
        k3s.role = "server";
      };

      styxeon = {
        hostId = "cc1aa076";
        wiredIp = "192.168.1.13";
        wirelessIp = "192.168.1.23";
        k3s.role = "agent";

        # This node runs the rippers. Serials verified against /dev/sr* on the
        # host; sg symlinks are needed because MakeMKV talks to the drives
        # through the SCSI-generic interface.
        opticalDrives =
          map
            (serial: {
              inherit serial;
              sg = true;
            })
            [
              "BP52225B18130019"
              "BP52225B18133253"
              "BP52225C07131304"
              "BP52425B18130826"
              "BP52524422173906"
              "BP52D24A16083824"
              "BP52E25510161815"
              "BP52E25512093803"
            ];
      };

      bytheon = {
        hostId = "3c436985";
        wiredInterface = "enp6s0";
        wirelessInterface = "wlo1";
        wiredIp = "192.168.1.14";
        wirelessIp = "192.168.1.24";
        k3s.role = "agent";
        gpu = "nvidia";
      };
    };
  };
}
