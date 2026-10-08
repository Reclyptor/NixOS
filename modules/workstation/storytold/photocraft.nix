# PhotoCraft — the suite's Photoshop equivalent, and the one with the deepest
# Adobe-format support: it reads and writes layered PSD/PSB.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "photocraft";
          version = "0.5.0";
          hash = "sha256-Ye8Fv4CPBUtqi1ZAJvXfpvyaXk7Ga9BAwl2nrsLEZWA=";
          cargoHash = "sha256-Id7pMLTkMvW/3/CESTGnWpdVVoF7yJLnbNMTQVt8n3s=";
          releaseDate = "2026-10-08";
          description = "Image editor for photos and layered PSD documents";

          # HEIC/HEIF decode, which 0.3.0 could not do: crates/heif landed after
          # that tag. It is off by default so distributors choose it, and
          # upstream's own packaging/linux/package.sh now builds with it. Costs no
          # native dependency — photocraft-heif wraps heic-rs, which is pure Rust.
          buildFeatures = [ "heif" ];

          # Build provenance, read at compile time by crates/engine/src/build_info.rs
          # and shown in --version and the About dialog. Unset, the binary calls
          # itself "0.5.0 (dev build)": a build that cannot name the commit it came
          # from is of no use in a bug report. Both values are properties of the pin
          # above, so stamping them costs nothing in reproducibility. The commit is
          # v0.5.0^{commit}, which upstream shortens to 9 characters for display.
          #
          # Alone in the suite: the other six carry no option_env! provenance at all.
          extraEnv = {
            PHOTOCRAFT_BUILD_SHA = "e5e3e397523b4db6a016dd19526e4c68514fcc72";
            PHOTOCRAFT_BUILD_DATE = "2026-10-08";
          };
        })
      ];
    };
}
