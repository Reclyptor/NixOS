{ config, ... }: {
  configurations.nixos.voideon = {
    imports = [
      ../../hardware/voideon.nix
      config.flake.modules.nixos.server
    ];

    host = {
      hostId = "1364e987";
      wiredIp = "192.168.1.12";
      wirelessIp = "192.168.1.22";
      k3s.role = "server";
    };
  };
}
