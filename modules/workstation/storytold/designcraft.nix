# DesignCraft — the InDesign equivalent. Reads IDML, writes PDF and EPUB.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "designcraft" (_: {
    version = "0.14.0";
    hash = "sha256-eQrDZN4ADUjXXAndAc1QNZ+LNGV0TLRJ4CopmzAwfBM=";
    cargoHash = "sha256-4TXmagOH4NbYSwHQ/M/8pjGQTWOoLDxuFA0yTPGtoDI=";
    releaseDate = "2026-10-28";
    description = "Page layout for magazines, books and print documents";
    craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";
  });
}
