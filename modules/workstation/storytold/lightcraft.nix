# LightCraft — the Lightroom equivalent: a photo catalog plus a non-destructive
# raw developer.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "lightcraft";
          version = "0.13.0";
          hash = "sha256-Na19eHTWkBZKjaRhU6V2RNnNExaxCuWrIIp4F9VwhUg=";
          cargoHash = "sha256-9gOmTjzqwwMdXFxBOgihSDtc0ywmZNvBzrVTRIaF2lQ=";
          releaseDate = "2026-10-23";
          description = "Photo library and non-destructive raw developer";
          craftFontsRev = "a71c20e30af613287c504f7e685ca8fad77752bc";

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
