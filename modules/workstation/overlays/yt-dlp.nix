{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        yt-dlp = prev.yt-dlp.overrideAttrs (oldAttrs: rec {
          version = "2026.07.04";
          src = prev.fetchFromGitHub {
            owner = "yt-dlp";
            repo = "yt-dlp";
            tag = version;
            hash = "sha256-+oHcVylLXFJTRR6jXF6IXvgntXJz0tRdtnwTruRPkoc=";
          };
        });
      })
    ];
  };
}
