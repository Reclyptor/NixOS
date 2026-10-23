# FilmCraft — the Premiere Pro equivalent. Carries the suite's demuxers and
# codecs (ISOBMFF, Matroska, MXF, MPEG-TS, H.264/HEVC, ProRes, DNxHD), which
# effectcraft then depends on by git rev.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "filmcraft";
          version = "0.12.0";
          hash = "sha256-NY6PABV6Jsg6Rahl3uSM8+qW61yAcAEhWzCDH+wDUMo=";
          cargoHash = "sha256-FWCOqH4tMJJjLUJc0z+F++PObsbAvDIzgdGt8rMUZSc=";
          releaseDate = "2026-10-23";
          description = "Video editor for picture, color and sound";
          craftFontsRev = "abb83316d96aa59c1cf64784289e378fe9fa5695";

          # Audio playback is ALSA (through cpal), and alsa-sys finds its headers
          # with pkg-config.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];

        })
      ];
    };
}
