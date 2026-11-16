# CADCraft — the AutoCAD equivalent: 2D drafting, dimensioning and plotting.
# Reads DXF and DWG.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "cadcraft" (_: {
    version = "0.20.1";
    hash = "sha256-VwytPvrzszX3a2Kvibu0luUhTXVNzhrEk049/0jnRP4=";
    cargoHash = "sha256-LgwdA0K8FhYvJFxXCNjm7y8m6A8qkayyMOgGFoxZS/E=";
    releaseDate = "2026-11-12";
    description = "2D drafting and plotting with DXF and DWG support";
    cliDocs = true;
    craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

    extraEnv = {
      CADCRAFT_BUILD_SHA = "7526dc62c14e71b3c8d46e73bbf1fa29ef506af1";
    };
  });
}
