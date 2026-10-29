# DeckCraft — the PowerPoint equivalent: building slide decks and presenting
# them. Reads and writes PPTX, with its own native deck format.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "deckcraft";
          version = "0.12.0";
          hash = "sha256-BWRINVloBo8oCobZ3eW0G5dcWrQ6jYZhuKMHvKUpcWA=";
          cargoHash = "sha256-befhMAAiQ1OZXfHXakmt9gU00/EEYaANLGEr9s1mKHM=";
          releaseDate = "2026-10-28";
          description = "Presentation editor for building and showing slide decks";
          craftFontsRev = "37827adc41fd165f9a9234ac40f94dbad353aa69";

          # Audio embedded in a slide plays through cpal, so the same ALSA pair the
          # editors need. Declared under nfpm `depends`, not `recommends`.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];

          extraEnv = {
            DECKCRAFT_BUILD_SHA = "29f0f7772c47aa2bfb74fcbb0c4d3b1503300849";
            DECKCRAFT_BUILD_DATE = "2026-10-28";
          };
        })
      ];
    };
}
