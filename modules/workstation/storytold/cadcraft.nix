# CADCraft — the AutoCAD equivalent: 2D drafting, dimensioning and plotting.
# Reads DXF and DWG.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "cadcraft";
          version = "0.3.0";
          hash = "sha256-VFw6np9BSOdBQrKlIiNnQ0kKKNfGnYMctbceBpmE778=";
          cargoHash = "sha256-R0nr3XMPU8nL9qV05bHDqW0YGa3pk3mu4kXIF31pm2U=";
          releaseDate = "2026-10-08";
          description = "2D drafting and plotting with DXF and DWG support";

          extraEnv = {
            CADCRAFT_BUILD_SHA = "59631c8d4f9ffe6c08c5c2065ea17504e53bf821";
          };
        })
      ];
    };
}
