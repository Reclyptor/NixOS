{ config, ... }:
{
  configurations.nixos.voideon = {
    imports = [
      ../../hardware/voideon.nix
      config.flake.modules.nixos.server
    ];

    host = config.fleet.nodes.voideon;
  };
}
