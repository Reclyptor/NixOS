# VectorCraft — the Illustrator equivalent. Reads and writes SVG and PDF.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "vectorcraft";
          version = "0.16.0";
          hash = "sha256-0NE4T55rwc1d6siV1RoeffAeh6uKoFY0YON23KYCQt4=";
          cargoHash = "sha256-Y3MJsI8tLwMPnae4COcgQ6+XS4GYcHF7cTPLnMmDO84=";
          releaseDate = "2026-10-23";
          description = "Vector graphics editor for illustrations, SVG and PDF";
          craftFontsRev = "a71c20e30af613287c504f7e685ca8fad77752bc";
        })
      ];
    };
}
