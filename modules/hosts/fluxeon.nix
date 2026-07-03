{ config, ... }: {
  configurations.nixos.fluxeon = {
    imports = [
      ../../hardware/fluxeon.nix
      config.flake.modules.nixos.server
    ];

    host = {
      hostId = "491bbece";
      wiredIp = "192.168.1.11";
      wirelessIp = "192.168.1.21";
      k3s.role = "server";
    };
  };
}
