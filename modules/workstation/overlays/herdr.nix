{ inputs, ... }:
{
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: _prev: {
        # Straight from the pinned input (which follows our nixpkgs), not
        # upstream's overlays.default — that one composes rust-overlay into the
        # whole package set to build one binary.
        herdr = inputs.herdr.packages.${final.system}.herdr;
      })
    ];
  };
}
