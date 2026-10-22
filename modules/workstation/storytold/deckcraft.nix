# DeckCraft — the PowerPoint equivalent: building slide decks and presenting
# them. Reads and writes PPTX, with its own native deck format.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "deckcraft";
          version = "0.8.0";
          hash = "sha256-kO8YBFzyip+NJmH2eFGGOB7OCOZWUhIGvEuxBzSemgk=";
          cargoHash = "sha256-TlPzzZqjfKPE0D6FUSQKYkfdENzED+zNRYfQxepEBzk=";
          releaseDate = "2026-10-18";
          description = "Presentation editor for building and showing slide decks";
          craftFontsRev = "43913056ce82a3fdad0ef69f6b88d1dc922a8104";

          # Audio embedded in a slide plays through cpal, so the same ALSA pair the
          # editors need. Declared under nfpm `depends`, not `recommends`.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];

          extraEnv = {
            DECKCRAFT_BUILD_SHA = "22db9261f9d1a214c296fd390173130c45d76d66";
            DECKCRAFT_BUILD_DATE = "2026-10-18";
          };
        })
      ];
    };
}
