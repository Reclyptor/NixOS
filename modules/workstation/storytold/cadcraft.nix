# CADCraft — the AutoCAD equivalent: 2D drafting, dimensioning and plotting.
# Reads DXF and DWG.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "cadcraft";
          version = "0.8.0";
          hash = "sha256-kJQAgQ9ebzSW2V4/pK2HxRuLLQfvZJ16miJshbYo0TU=";
          cargoHash = "sha256-ql6+1TmAhoDumKI7YbTE0gVSoRa0yr0amaH0OIKF+os=";
          releaseDate = "2026-10-17";
          description = "2D drafting and plotting with DXF and DWG support";
          craftFontsRev = "3d9ab3a132ed0eff457e424226a435a901da30d3";

          extraEnv = {
            CADCRAFT_BUILD_SHA = "714111d528acc86dc6b41e03f9a82cabc1066dca";
          };
        })
      ];
    };
}
