{ config, pkgs, lib, ... }: (
  let homeDirectory = ./home; in {
    home.username = "reclyptor";
    home.homeDirectory = "/home/reclyptor";
    home.stateVersion = "24.11";
  
    home.packages = with pkgs; [];
  
    imports = builtins.attrValues (
      lib.genAttrs 
        (builtins.attrNames (builtins.readDir homeDirectory))
        (name: import (homeDirectory + "/${name}"))
    );
  
    programs.home-manager.enable = true;
  }
)