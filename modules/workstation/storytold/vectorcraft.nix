# VectorCraft — the Illustrator equivalent. Reads and writes SVG and PDF.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "vectorcraft" (_: {
    version = "0.24.1";
    hash = "sha256-d6euwjY0zs+JW7hM2Sqgsb+nHoLps7JhmDCGo24elHc=";
    cargoHash = "sha256-K5Pm4G+8alH0mtyu6kyWP7/wc+OPmI1JBp15wvBKsb0=";
    releaseDate = "2026-11-12";
    description = "Vector graphics editor for illustrations, SVG and PDF";
    craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";
  });
}
