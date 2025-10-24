{ config, pkgs, lib, ... }: (
  let bashDirectory = ./.; in {
    programs.bash = {
      enable = true;
      enableCompletion = true;
    };
  
    imports = builtins.filter (path: path != ./default.nix) (
      builtins.attrValues (
        lib.genAttrs 
          (builtins.attrNames (builtins.readDir bashDirectory))
          (name: bashDirectory + "/${name}")
      )
    );
  }
)