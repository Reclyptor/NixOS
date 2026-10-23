# SoundCraft — the Pro Tools equivalent: a digital audio workstation for
# recording, editing and mixing audio and MIDI.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "soundcraft";
          version = "0.12.1";
          hash = "sha256-KiNJ/iVR8QHW6z6BBTS3n1TCGsFsWkY2N+OMyywjND0=";
          cargoHash = "sha256-JHI2cqHfGYMn9e8QmRDt16sKc5mdIbjo/ajSnGMGpLA=";
          releaseDate = "2026-10-22";
          description = "Digital audio workstation for audio and MIDI";

          # The one app in the suite where ALSA is the whole point rather than
          # playback for something else.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
