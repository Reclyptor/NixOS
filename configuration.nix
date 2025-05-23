{ config, pkgs, lib, ... }: (
  let moduleDirectory = ./modules; in {
    system.stateVersion = "24.11";
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    imports = builtins.attrValues (lib.genAttrs (builtins.attrNames (builtins.readDir moduleDirectory)) (name: import (moduleDirectory + "/${name}")));
  }
)
