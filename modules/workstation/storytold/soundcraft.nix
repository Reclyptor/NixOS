# SoundCraft — the Pro Tools equivalent: a digital audio workstation for
# recording, editing and mixing audio and MIDI.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "soundcraft" (
    { pkgs, ... }: {
      version = "0.20.1";
      hash = "sha256-Qew1WjgKWQ58OPZrhHVZRlKkj7u1EjwP9fgEOjKwfkw=";
      cargoHash = "sha256-rZzO2+VoVp/1nE/fHQ8hqsu7sFEVQX1AFMsPUOjRIK8=";
      releaseDate = "2026-11-12";
      description = "Digital audio workstation for audio and MIDI";
      cliDocs = true;

      # The one app in the suite where ALSA is the whole point rather than
      # playback for something else.
      extraNativeBuildInputs = [ pkgs.pkg-config ];
      extraBuildInputs = [ pkgs.alsa-lib ];
    }
  );
}
