{ config, ... }: {
  configurations.nixos.archeon = {
    imports = [
      ../../hardware/archeon.nix
      config.flake.modules.nixos.server
    ];

    host = {
      hostId = "4ea934c3";
      wiredIp = "192.168.1.10";
      wirelessIp = "192.168.1.20";
      k3s = { role = "server"; bootstrap = true; };
    };
  };
}
