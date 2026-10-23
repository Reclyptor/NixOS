# CADCraft — the AutoCAD equivalent: 2D drafting, dimensioning and plotting.
# Reads DXF and DWG.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "cadcraft";
          version = "0.12.0";
          hash = "sha256-JkpiJvU/Pk00q52lL1/LehJKIX5kHKMLQhhgxZdmRYs=";
          cargoHash = "sha256-lfoYEl44uFPdl5YYBOlsYUFlU00eDHnILcOGcrFc1BM=";
          releaseDate = "2026-10-23";
          description = "2D drafting and plotting with DXF and DWG support";
          craftFontsRev = "3d9ab3a132ed0eff457e424226a435a901da30d3";

          extraEnv = {
            CADCRAFT_BUILD_SHA = "bad1073fdf10a521949f6b542837b564719d0023";
          };
        })
      ];
    };
}
