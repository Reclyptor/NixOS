# GridCraft — the Excel equivalent: workbooks, formulas and charts. Reads and
# writes XLSX, including macro-enabled workbooks, plus CSV and TSV.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "gridcraft";
          version = "0.13.0";
          hash = "sha256-L1kbIku3WX/7pU/DpTqy2A2yT/+7vQVoK+iUYf5Dkpk=";
          cargoHash = "sha256-gudikEONztiu7cfkt87CTIydKQEfPNgvRBTobzXz3qM=";
          releaseDate = "2026-10-28";
          description = "Spreadsheet for calculating, analyzing and charting data";
          # crates/ui-egui/build.rs reads CRAFT_FONTS_DIR as of 0.13.0; before that
          # GridCraft embedded no craft-fonts at all.
          craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";
        })
      ];
    };
}
