{ config, ... }:
{
  configurations.nixos.bytheon = {
    imports = [
      ../../hardware/bytheon.nix
      config.flake.modules.nixos.server
    ];

    host = config.fleet.nodes.bytheon;
  };
}
