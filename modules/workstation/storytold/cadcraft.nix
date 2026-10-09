# CADCraft — the AutoCAD equivalent: 2D drafting, dimensioning and plotting.
# Reads DXF and DWG.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "cadcraft";
          version = "0.7.0";
          hash = "sha256-/7mlDxYCeE6vKKJWghfMj4WtHbjPWfPnhb+HoHgA0q4=";
          cargoHash = "sha256-7/TxuM5jh6fncL0+pAT147GJuri/sD0xnN6lRxueD0E=";
          releaseDate = "2026-10-14";
          description = "2D drafting and plotting with DXF and DWG support";
          craftFontsRev = "3d9ab3a132ed0eff457e424226a435a901da30d3";

          extraEnv = {
            CADCRAFT_BUILD_SHA = "fc4e98315a8d771b5ab832f0ade0b5e7b106df7f";
          };
        })
      ];
    };
}
