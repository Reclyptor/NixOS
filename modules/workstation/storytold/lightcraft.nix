# LightCraft — the Lightroom equivalent: a photo catalog plus a non-destructive
# raw developer.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "lightcraft";
          version = "0.9.1";
          hash = "sha256-zjud9GW1oTGlL2IA4dNH5LKmYAqAU9EyPIvTryW19RM=";
          cargoHash = "sha256-aVfcTaecTHpsZHDmTw9Js+4MfY1QHgaDzq/Sd2+Ckg4=";
          releaseDate = "2026-10-18";
          description = "Photo library and non-destructive raw developer";
          craftFontsRev = "3d9ab3a132ed0eff457e424226a435a901da30d3";

          # HEIC/HEIF decode, new in 0.6.0 and built by upstream's package.sh. Off by
          # default so distributors choose it, and enabled per package rather than
          # workspace-wide because the gui and cli each gate it separately. Like
          # photocraft's, lightcraft-heif wraps heic-rs, pure Rust, so it costs no
          # native dependency.
          buildFeatures = [
            "lightcraft/heif"
            "lightcraft-cli/heif"
          ];
        })
      ];
    };
}
