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
          version = "0.4.0";
          hash = "sha256-qM8o8rSiiGBif0UePQpn6aAEzqbjIMx3ZRoE3wA1yFI=";
          cargoHash = "sha256-uzDeo+94RAK/flnYgTic167BeYfk2zqwwf/ODbwnok0=";
          releaseDate = "2026-10-08";
          description = "Video editor for picture, color and sound";

          # Audio playback is ALSA (through cpal), and alsa-sys finds its headers
          # with pkg-config.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
