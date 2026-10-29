# LightCraft — the Lightroom equivalent: a photo catalog plus a non-destructive
# raw developer.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "lightcraft";
          version = "0.15.0";
          hash = "sha256-oXvuQpFZZMntX1wY8Q+ZpF7TUoamosY9aDbD614JgjA=";
          cargoHash = "sha256-gQNlh3QElGyWu6jnfdDHaJol5FT3FlN6ylXBZYP2z+4=";
          releaseDate = "2026-10-28";
          description = "Photo library and non-destructive raw developer";
          craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

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
