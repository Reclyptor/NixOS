{ config, ... }: {
  configurations.nixos.bytheon = {
    imports = [
      ../../hardware/bytheon.nix
      config.flake.modules.nixos.server
    ];

    host = {
      hostId = "3c436985";
      wiredInterface = "enp6s0";
      wirelessInterface = "wlo1";
      wiredIp = "192.168.1.14";
      wirelessIp = "192.168.1.24";
      k3s.role = "agent";
      gpu = "nvidia";
    };
  };
}
