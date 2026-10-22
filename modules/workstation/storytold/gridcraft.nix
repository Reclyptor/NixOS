# GridCraft — the Excel equivalent: workbooks, formulas and charts. Reads and
# writes XLSX, including macro-enabled workbooks, plus CSV and TSV.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "gridcraft";
          version = "0.8.0";
          hash = "sha256-G0xsNWRoNMtA5lTKSZgLCHP6gcq+zOaOPdcColuFr0A=";
          cargoHash = "sha256-EY/41uMNm9hG7LhynI4d/7RSj5tGXsT8/s+Al8mr7pk=";
          releaseDate = "2026-10-18";
          description = "Spreadsheet for calculating, analyzing and charting data";
        })
      ];
    };
}
