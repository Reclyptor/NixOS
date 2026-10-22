# VectorCraft — the Illustrator equivalent. Reads and writes SVG and PDF.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "vectorcraft";
          version = "0.13.1";
          hash = "sha256-6fnvggL1zSNnO2w32zKpgtE2bv/4SWs//uAEDR+UFIo=";
          cargoHash = "sha256-3bE4+qcKPubcfJ3ZDTKzqh+xT325qNFR08rSxRhny6E=";
          releaseDate = "2026-10-18";
          description = "Vector graphics editor for illustrations, SVG and PDF";
          craftFontsRev = "3d9ab3a132ed0eff457e424226a435a901da30d3";
        })
      ];
    };
}
