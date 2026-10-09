# GridCraft — the Excel equivalent: workbooks, formulas and charts. Reads and
# writes XLSX, including macro-enabled workbooks, plus CSV and TSV.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "gridcraft";
          version = "0.7.0";
          hash = "sha256-8qlbNJWvONfZ8BvY8fij1QrLwoikFKBgmTiklpu4LOM=";
          cargoHash = "sha256-9PJmE7dLeDIEsnczga1WfWaad1e0YLLh04rJcSyzGwE=";
          releaseDate = "2026-10-14";
          description = "Spreadsheet for calculating, analyzing and charting data";
        })
      ];
    };
}
