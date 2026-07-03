{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        yt-dlp = prev.yt-dlp.overrideAttrs (oldAttrs: rec {
          version = "2026.06.09";
          src = prev.fetchFromGitHub {
            owner = "yt-dlp";
            repo = "yt-dlp";
            tag = version;
            hash = "sha256-ykqTDPzKKIWRGSQmw2esCRKyYqDZKXRYDeba888tkDU=";
          };
        });
      })
    ];
  };
}
