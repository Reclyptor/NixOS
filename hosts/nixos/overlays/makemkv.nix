{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      makemkv = prev.makemkv.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [ prev.expat ];
      });
    })
  ];
}
