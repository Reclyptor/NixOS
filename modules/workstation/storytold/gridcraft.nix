# GridCraft — the Excel equivalent: workbooks, formulas and charts. Reads and
# writes XLSX, including macro-enabled workbooks, plus CSV and TSV.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "gridcraft";
          version = "0.11.1";
          hash = "sha256-ZhaRTAPX+bnifFTgU7Pv5wFaJHmffXI0a0vAyF4A0cs=";
          cargoHash = "sha256-eQMyzLQGDw444ZPpw01jbJkoWXWlWfGvWoQCd9mYr50=";
          releaseDate = "2026-10-22";
          description = "Spreadsheet for calculating, analyzing and charting data";
        })
      ];
    };
}
