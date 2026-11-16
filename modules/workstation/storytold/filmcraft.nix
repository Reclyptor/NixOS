# FilmCraft — the Premiere Pro equivalent. Carries the suite's demuxers and
# codecs (ISOBMFF, Matroska, MXF, MPEG-TS, H.264/HEVC, ProRes, DNxHD), which
# effectcraft then depends on by git rev.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "filmcraft" (
    { pkgs, ... }: {
      version = "0.20.1";
      hash = "sha256-efnUlfnS56t760z0hwQHGUtp4x7zzKnW6BJkyWwa1RQ=";
      cargoHash = "sha256-aQnPf3S3Mx/TsMNdbms2C2ACc4Zitggvw3PWcLEEZuI=";
      releaseDate = "2026-11-12";
      description = "Video editor for picture, color and sound";
      craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

      # Audio playback is ALSA (through cpal), and alsa-sys finds its headers
      # with pkg-config.
      extraNativeBuildInputs = [ pkgs.pkg-config ];
      extraBuildInputs = [ pkgs.alsa-lib ];

      # Kokoro text-to-speech voices, which upstream's package.sh builds with
      # since 0.20. Pure Rust, no native dependency; the voice models are
      # downloaded by the app when first used, not at build time.
      buildFeatures = [ "filmcraft/neural-voices" ];
    }
  );
}
