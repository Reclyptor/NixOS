# DeckCraft — the PowerPoint equivalent: building slide decks and presenting
# them. Reads and writes PPTX, with its own native deck format.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "deckcraft" (
    { pkgs, ... }: {
      version = "0.18.1";
      hash = "sha256-nNoZvhnGEFNmh780GtHoQ4jczs65laFRq7+bF4akXTg=";
      cargoHash = "sha256-IReMe4glJWfNEoLYLcL1GiahvjUSM60oEV576ATNII0=";
      releaseDate = "2026-11-12";
      description = "Presentation editor for building and showing slide decks";
      craftFontsRev = "37827adc41fd165f9a9234ac40f94dbad353aa69";

      # Audio embedded in a slide plays through cpal, so the same ALSA pair the
      # editors need. Declared under nfpm `depends`, not `recommends`.
      extraNativeBuildInputs = [ pkgs.pkg-config ];
      extraBuildInputs = [ pkgs.alsa-lib ];

      extraEnv = {
        DECKCRAFT_BUILD_SHA = "7cc73ab1895ed2e30c8afbcada20c70b9ea0a440";
        DECKCRAFT_BUILD_DATE = "2026-11-12";
      };
    }
  );
}
