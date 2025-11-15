{ config, pkgs, lib, ... }: 
let 
  moduleDirectory = ./modules;
in {
  system.stateVersion = "25.05";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  networking.hostName = "voideon";
  
  imports = [
    ./hardware-configuration.nix
  ] ++ (builtins.attrValues (lib.genAttrs 
    (builtins.attrNames (builtins.readDir moduleDirectory)) 
    (name: import (moduleDirectory + "/${name}"))));
}
