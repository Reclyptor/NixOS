# DeckCraft — the PowerPoint equivalent: building slide decks and presenting
# them. Reads and writes PPTX, with its own native deck format.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "deckcraft";
          version = "0.3.0";
          hash = "sha256-mJTA41rZMHwrK8o/Yw2TcGfWSfz7MreX9SliFVAoDMc=";
          cargoHash = "sha256-apWpS5qjLkXMXfzR21NEt7EyuoMk489DVS1rKp9rVcA=";
          releaseDate = "2026-10-08";
          description = "Presentation editor for building and showing slide decks";

          # Audio embedded in a slide plays through cpal, so the same ALSA pair the
          # editors need. Declared under nfpm `depends`, not `recommends`.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];

          extraEnv = {
            DECKCRAFT_BUILD_SHA = "d0e57d7e25f9852179cc66be12dd6188f1c05535";
            DECKCRAFT_BUILD_DATE = "2026-10-08";
          };
        })
      ];
    };
}
