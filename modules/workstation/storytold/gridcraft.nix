# GridCraft — the Excel equivalent: workbooks, formulas and charts. Reads and
# writes XLSX, including macro-enabled workbooks, plus CSV and TSV.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "gridcraft";
          version = "0.3.0";
          hash = "sha256-C7MOB7YvkYG3aE3PAEtRChdYCRi2tTfu6d/qQhTNX+c=";
          cargoHash = "sha256-lYyBPwE04DrNzUtYPV3aH0mDFuryE/AWesDzV8W2NqA=";
          releaseDate = "2026-10-08";
          description = "Spreadsheet for calculating, analyzing and charting data";
        })
      ];
    };
}
