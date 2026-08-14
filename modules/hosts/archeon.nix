{ config, ... }:
{
  configurations.nixos.archeon = {
    imports = [
      ../../hardware/archeon.nix
      config.flake.modules.nixos.server
    ];

    host = config.fleet.nodes.archeon;
  };
}
