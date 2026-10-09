# SoundCraft — the Pro Tools equivalent: a digital audio workstation for
# recording, editing and mixing audio and MIDI.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "soundcraft";
          version = "0.7.0";
          hash = "sha256-5jtnIqtpPF68JQfIGIjXHrW//4Xwkzs7OOXGKZ6hfxg=";
          cargoHash = "sha256-E6TBJJMjLX2D5DvzSdy5HPxhSq2IG+rz2VtD2wkN+dQ=";
          releaseDate = "2026-10-14";
          description = "Digital audio workstation for audio and MIDI";

          # The one app in the suite where ALSA is the whole point rather than
          # playback for something else.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
