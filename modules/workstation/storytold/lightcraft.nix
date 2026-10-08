# LightCraft — the Lightroom equivalent: a photo catalog plus a non-destructive
# raw developer.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "lightcraft";
          version = "0.8.0";
          hash = "sha256-a84KDuTcYNsf5Te4U2PYOp2P1VwK0sGoJ0qIxaRjR80=";
          cargoHash = "sha256-i+y4+1xTg9F1fxO0gdFU/ZxTRWsB+NHfOJKdNNWGtqs=";
          releaseDate = "2026-10-14";
          description = "Photo library and non-destructive raw developer";

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
