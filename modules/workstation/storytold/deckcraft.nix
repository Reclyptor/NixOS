# DeckCraft — the PowerPoint equivalent: building slide decks and presenting
# them. Reads and writes PPTX, with its own native deck format.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "deckcraft";
          version = "0.10.0";
          hash = "sha256-q18YQXHmkPaULSMPxu5vY9/F7JThejIhKwpHhme0UCI=";
          cargoHash = "sha256-iHkyrHz2VMx0+bpYnve5EtBiuH32VSYHRSvg+ihIdwU=";
          releaseDate = "2026-10-22";
          description = "Presentation editor for building and showing slide decks";
          craftFontsRev = "43913056ce82a3fdad0ef69f6b88d1dc922a8104";

          # Audio embedded in a slide plays through cpal, so the same ALSA pair the
          # editors need. Declared under nfpm `depends`, not `recommends`.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];

          extraEnv = {
            DECKCRAFT_BUILD_SHA = "b47195feec0f0fe4220d8943ad1c8add5dad8072";
            DECKCRAFT_BUILD_DATE = "2026-10-22";
          };
        })
      ];
    };
}
