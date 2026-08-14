{ config, ... }:
{
  configurations.nixos.fluxeon = {
    imports = [
      ../../hardware/fluxeon.nix
      config.flake.modules.nixos.server
    ];

    host = config.fleet.nodes.fluxeon;
  };
}
