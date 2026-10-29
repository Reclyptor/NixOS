# PhotoCraft — the suite's Photoshop equivalent, and the one with the deepest
# Adobe-format support: it reads and writes layered PSD/PSB.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "photocraft";
          version = "0.17.0";
          hash = "sha256-oN6ML1ua31tUzvhB6pfoTrs1VePkH9lM1AXUwLbH97s=";
          cargoHash = "sha256-vHvLLkzPIcUetxDbDSbTkTYYuAByGxKb7uWAhkoivXE=";
          releaseDate = "2026-10-28";
          description = "Image editor for photos and layered PSD documents";
          craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

          # HEIC/HEIF decode, which 0.3.0 could not do: crates/heif landed after
          # that tag. It is off by default so distributors choose it, and
          # upstream's own packaging/linux/package.sh now builds with it. Costs no
          # native dependency — photocraft-heif wraps heic-rs, which is pure Rust.
          buildFeatures = [ "heif" ];

          # photocraft-cli's man pages and bash, zsh and fish completions, new in
          # 0.16.0 and shipped by upstream's package.sh, which writes them with
          # examples/man-and-completions.rs.
          cliDocs = true;

          # Cargo.lock lists pipewire-sys since 0.7.0 and aws-lc-sys since 0.9.0, which
          # would want libpipewire, cmake and a libclang. Both are Windows-only paths:
          # pipewire arrives through xcap, the screen eyedropper's capture crate, and
          # aws-lc through craft-print -> winprint, which verifies a PDFium download.
          # apps/photocraft/Cargo.toml and craft-print gate both behind
          # cfg(target_os = "windows"). Nothing here builds either, so no input is
          # added.
          #
          # It also lists yeslogic-fontconfig-sys, which would want pkg-config and
          # the fontconfig headers. That one is macOS-only: crates/text turns on
          # parley's `system` feature under cfg(target_os = "macos") alone, for
          # fontique's Core Text backend, and the Linux build scans font folders
          # itself. `cargo tree --target x86_64-unknown-linux-gnu -i` finds nothing
          # depending on it.

          # Build provenance, read at compile time by crates/engine/src/build_info.rs
          # and shown in --version and the About dialog. Unset, the binary calls
          # itself "0.17.0 (dev build)": a build that cannot name the commit it came
          # from is of no use in a bug report. Both values are properties of the pin
          # above, so stamping them costs nothing in reproducibility. The commit is
          # v0.17.0^{commit}, which upstream shortens to 9 characters for display.
          #
          # The only one of the seven ArtCraft apps that reads a provenance; of the
          # rest of the suite, wordcraft, deckcraft, cadcraft and figcraft do too.
          extraEnv = {
            PHOTOCRAFT_BUILD_SHA = "b8c3f3aa8e2918032cadc0e042664414a03be333";
            PHOTOCRAFT_BUILD_DATE = "2026-10-28";
          };
        })
      ];
    };
}
