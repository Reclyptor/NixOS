# DeckCraft — the PowerPoint equivalent: building slide decks and presenting
# them. Reads and writes PPTX, with its own native deck format.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "deckcraft";
          version = "0.7.0";
          hash = "sha256-MEocLbrEyQ2X+YTxmbsqg69Eox/X7NIFySvuFDMbKV8=";
          cargoHash = "sha256-K02kLzGc/TxFAifSqqpgLWRyM/egWlasQxSjFSEk1Ms=";
          releaseDate = "2026-10-14";
          description = "Presentation editor for building and showing slide decks";
          craftFontsRev = "43913056ce82a3fdad0ef69f6b88d1dc922a8104";

          # Audio embedded in a slide plays through cpal, so the same ALSA pair the
          # editors need. Declared under nfpm `depends`, not `recommends`.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];

          extraEnv = {
            DECKCRAFT_BUILD_SHA = "d78e657e4cb1e490ceb5445785c052d9cf5ad963";
            DECKCRAFT_BUILD_DATE = "2026-10-14";
          };
        })
      ];
    };
}
