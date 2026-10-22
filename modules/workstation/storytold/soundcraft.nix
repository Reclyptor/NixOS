# SoundCraft — the Pro Tools equivalent: a digital audio workstation for
# recording, editing and mixing audio and MIDI.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "soundcraft";
          version = "0.8.0";
          hash = "sha256-SI58vpqyig1J1l81rqNRrIEhAgpE/mq/nSOjUxn8910=";
          cargoHash = "sha256-+XQMm8RB2MvuJRGddTZDVM3qRG7hHY7vM5xuxeqsG4o=";
          releaseDate = "2026-10-17";
          description = "Digital audio workstation for audio and MIDI";

          # The one app in the suite where ALSA is the whole point rather than
          # playback for something else.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
