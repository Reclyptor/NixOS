# CADCraft — the AutoCAD equivalent: 2D drafting, dimensioning and plotting.
# Reads DXF and DWG.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "cadcraft";
          version = "0.14.0";
          hash = "sha256-53ahBBFBYCLJuQU/QjJ4gBvTHwZW+pAj28iYNHtXvro=";
          cargoHash = "sha256-DYbtPJBQGipVxRYZbiv4q02Ga8FdAysQWx+fgTGoqWA=";
          releaseDate = "2026-10-28";
          description = "2D drafting and plotting with DXF and DWG support";
          cliDocs = true;
          craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

          extraEnv = {
            CADCRAFT_BUILD_SHA = "fbd97d432cdf36a566c0c53739481bd6f0c32b0d";
          };
        })
      ];
    };
}
