{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      yt-dlp = prev.yt-dlp.overrideAttrs (oldAttrs: rec {
        version = "2026.02.04";
        src = prev.fetchFromGitHub {
          owner = "yt-dlp";
          repo = "yt-dlp";
          tag = version;
          hash = "sha256-KXnz/ocHBftenDUkCiFoBRBxi6yWt0fNuRX+vKFWDQw=";
        };
        postPatch = builtins.replaceStrings
          [ "< (0, 14)" ]
          [ "< (0, 15)" ]
          oldAttrs.postPatch;
      });
    })
  ];
}
