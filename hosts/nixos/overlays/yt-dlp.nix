{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      yt-dlp = prev.yt-dlp.overrideAttrs (oldAttrs: rec {
        version = "2026.03.03";
        src = prev.fetchFromGitHub {
          owner = "yt-dlp";
          repo = "yt-dlp";
          tag = version;
          hash = "sha256-BPZzMT1IrZvgva/m5tYMaDYoUaP3VmpmcYeOUOwuoUY=";
        };
        postPatch = builtins.replaceStrings
          [ "< (0, 14)" ]
          [ "< (0, 15)" ]
          oldAttrs.postPatch;
      });
    })
  ];
}
