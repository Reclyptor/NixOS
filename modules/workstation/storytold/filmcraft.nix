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
          version = "0.9.0";
          hash = "sha256-GQHgXZwEQcBfCZMxZMfPmoKXZvS9PwX99/Mq7aq34n8=";
          cargoHash = "sha256-ilrMSVA0T1gQJRgCe+m8Vr2QTJMBZFas/gaYJ1+pttg=";
          releaseDate = "2026-10-18";
          description = "Video editor for picture, color and sound";
          craftFontsRev = "abb83316d96aa59c1cf64784289e378fe9fa5695";

          # Audio playback is ALSA (through cpal), and alsa-sys finds its headers
          # with pkg-config.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];

          # This test pins the desktop entry apps/filmcraft/src/dev_icon.rs writes
          # for source-tree runs (opt-in, FILMCRAFT_DEV_DESKTOP_ENTRY=1) to the
          # packaged one. Upstream's 69a6c4b6 added MimeType= to the packaged entry
          # but not to the generator, so it fails from 0.8.0 on, and upstream's CI
          # does not run it on Linux. We install the packaged entry itself and never
          # the generated one, so the drift does not reach this package.
          checkFlags = [ "--skip=dev_icon::tests::desktop_file_matches_the_packaged_fields" ];
        })
      ];
    };
}
