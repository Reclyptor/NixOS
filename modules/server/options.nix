{ ... }: {
  # Everything that actually differs between the five cluster nodes lives in
  # these options; the rest of modules/server/ is shared verbatim.
  flake.modules.nixos.server = { lib, ... }: {
    options.host = {
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
        type = lib.types.enum [ "server" "agent" ];
        description = "k3s role: control-plane server or worker agent.";
      };

      k3s.bootstrap = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this node initialized the cluster (clusterInit); all others join via the local API load balancer.";
      };

      gpu = lib.mkOption {
        type = lib.types.enum [ "amd" "nvidia" ];
        default = "amd";
        description = "GPU vendor; selects kernel modules, drivers, and tooling.";
      };

      opticalDriveRules = lib.mkOption {
        type = lib.types.lines;
        description = "udev rules mapping this node's optical drives to stable /dev symlinks (per-host hardware inventory).";
      };
    };
  };
}
