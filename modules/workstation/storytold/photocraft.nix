# PhotoCraft — the suite's Photoshop equivalent, and the one with the deepest
# Adobe-format support: it reads and writes layered PSD/PSB.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "photocraft";
          version = "0.9.0";
          hash = "sha256-muKVyGM/lG0Ffav5wk4SbinrPkoCzvBYmcpM/Vwp6bk=";
          cargoHash = "sha256-PQZGEtDvB6qb2arHuxGfz7Z+Pr1mCF/MrMI2yUGoV74=";
          releaseDate = "2026-10-14";
          description = "Image editor for photos and layered PSD documents";
          craftFontsRev = "abb83316d96aa59c1cf64784289e378fe9fa5695";

          # HEIC/HEIF decode, which 0.3.0 could not do: crates/heif landed after
          # that tag. It is off by default so distributors choose it, and
          # upstream's own packaging/linux/package.sh now builds with it. Costs no
          # native dependency — photocraft-heif wraps heic-rs, which is pure Rust.
          buildFeatures = [ "heif" ];

          # Cargo.lock lists pipewire-sys since 0.7.0 and aws-lc-sys since 0.9.0, which
          # would want libpipewire, cmake and a libclang. Both are Windows-only paths:
          # pipewire arrives through xcap, the screen eyedropper's capture crate, and
          # aws-lc through craft-print -> winprint, which verifies a PDFium download.
          # apps/photocraft/Cargo.toml and craft-print gate both behind
          # cfg(target_os = "windows"). Nothing here builds either, so no input is
          # added.

          # Build provenance, read at compile time by crates/engine/src/build_info.rs
          # and shown in --version and the About dialog. Unset, the binary calls
          # itself "0.9.0 (dev build)": a build that cannot name the commit it came
          # from is of no use in a bug report. Both values are properties of the pin
          # above, so stamping them costs nothing in reproducibility. The commit is
          # v0.9.0^{commit}, which upstream shortens to 9 characters for display.
          #
          # The only one of the seven ArtCraft apps that reads a provenance; of the
          # rest of the suite, wordcraft, deckcraft, cadcraft and figcraft do too.
          extraEnv = {
            PHOTOCRAFT_BUILD_SHA = "c699e3cda69f4852b43c0b191ab0091aaeff9d6a";
            PHOTOCRAFT_BUILD_DATE = "2026-10-14";
          };
        })
      ];
    };
}
