{ config, ... }:
{
  configurations.nixos.styxeon = {
    imports = [
      ../../hardware/styxeon.nix
      config.flake.modules.nixos.server
    ];

    host = config.fleet.nodes.styxeon;
  };
}
