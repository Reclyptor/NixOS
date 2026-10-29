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
          version = "0.14.0";
          hash = "sha256-2UvPxCyhRT7XMXZqX1aHArLuL0VUo3hC5a8q2WFph6w=";
          cargoHash = "sha256-uStVTwwZBP396uyBjdu+aF+zMqQVaZrn7cw14Nd2U4Y=";
          releaseDate = "2026-10-28";
          description = "Video editor for picture, color and sound";
          craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

          # Audio playback is ALSA (through cpal), and alsa-sys finds its headers
          # with pkg-config.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
