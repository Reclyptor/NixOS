{ inputs, ... }: {
  flake.modules.nixos.workstation = { ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        # Tracks yt-dlp master via the flake input; extractors break often
        # enough that the tagged releases in nixpkgs lag real-world fixes.
        yt-dlp = prev.yt-dlp.overrideAttrs {
          version = "0-unstable-${inputs.yt-dlp.shortRev}";
          src = inputs.yt-dlp;
        };
      })
    ];
  };
}
