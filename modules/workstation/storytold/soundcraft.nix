# SoundCraft — the Pro Tools equivalent: a digital audio workstation for
# recording, editing and mixing audio and MIDI.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "soundcraft";
          version = "0.14.0";
          hash = "sha256-u6aRlfonVjzK6HRfXWDftz118sD3/OR/ZcoALXiky3A=";
          cargoHash = "sha256-lysmnO12fqA0fJrmunX3kQXWpYPCmJ719LFm4WUwsXY=";
          releaseDate = "2026-10-28";
          description = "Digital audio workstation for audio and MIDI";
          cliDocs = true;

          # The one app in the suite where ALSA is the whole point rather than
          # playback for something else.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
