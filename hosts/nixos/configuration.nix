{ config, pkgs, lib, ... }: (
  let
    moduleDirectory = ./modules; 
    overlayDirectory = ./overlays;
  in {
    system.stateVersion = "25.11";
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
    services.zfs.autoScrub.enable = true;
    services.zfs.trim.enable = true;
    zramSwap.enable = true;
    imports = builtins.attrValues (lib.genAttrs (builtins.attrNames (builtins.readDir moduleDirectory)) (name: import (moduleDirectory + "/${name}")))
      ++ builtins.attrValues (lib.genAttrs (builtins.attrNames (builtins.readDir overlayDirectory)) (name: import (overlayDirectory + "/${name}")));
  }
)
