{ lib, ... }:

let
  pkgModulesDir = ./packages;
  pkgModules = builtins.attrValues (lib.genAttrs (builtins.attrNames (builtins.readDir pkgModulesDir)) (name: import (pkgModulesDir + "/${name}")));
in {
  imports = pkgModules;
}
