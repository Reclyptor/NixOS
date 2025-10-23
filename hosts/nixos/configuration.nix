{ config, pkgs, lib, ... }: (
  let moduleDirectory = ../../modules; in {
    system.stateVersion = "24.11";
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      warn-dirty = false;
    };
    nix.gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    imports = builtins.attrValues (lib.genAttrs (builtins.attrNames (builtins.readDir moduleDirectory)) (name: import (moduleDirectory + "/${name}")));
  }
)
