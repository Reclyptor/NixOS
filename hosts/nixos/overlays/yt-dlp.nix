{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      yt-dlp = prev.yt-dlp.overrideAttrs (oldAttrs: rec {
        version = "2026.01.31";
        src = prev.fetchFromGitHub {
          owner = "yt-dlp";
          repo = "yt-dlp";
          tag = version;
          hash = "sha256-3sXXyWuQI6KTOQIkkOfJhCTBBh3Zkv59ENhkrz9Sgxc=";
        };
        postPatch = builtins.replaceStrings
          [ "< (0, 14)" ]
          [ "< (0, 15)" ]
          oldAttrs.postPatch;
      });
    })
  ];
}
