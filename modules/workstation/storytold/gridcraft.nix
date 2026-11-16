# GridCraft — the Excel equivalent: workbooks, formulas and charts. Reads and
# writes XLSX, including macro-enabled workbooks, plus CSV and TSV.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "gridcraft" (_: {
    version = "0.19.1";
    hash = "sha256-/dkhjj+BcL/+b/psYpRdO/vEG0zpiAt5fpIqkG7WLMw=";
    cargoHash = "sha256-vkNDu60fJy9GOqQSqZItees+XOmta1qB5x5ibm8nBuM=";
    releaseDate = "2026-11-12";
    description = "Spreadsheet for calculating, analyzing and charting data";
    # crates/ui-egui/build.rs reads CRAFT_FONTS_DIR as of 0.13.0; before that
    # GridCraft embedded no craft-fonts at all.
    craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";
  });
}
