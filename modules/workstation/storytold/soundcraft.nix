# SoundCraft — the Pro Tools equivalent: a digital audio workstation for
# recording, editing and mixing audio and MIDI.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "soundcraft";
          version = "0.3.0";
          hash = "sha256-VdTwPoLrLq3XxevWWo06WF16f/6/+x9cQ/kS3swkreE=";
          cargoHash = "sha256-3ujhZk0bkdDuRPX6z6fTliHzjuaVGrdcXCyMu7906Uk=";
          releaseDate = "2026-10-08";
          description = "Digital audio workstation for audio and MIDI";

          # The one app in the suite where ALSA is the whole point rather than
          # playback for something else.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
