{ inputs, ... }:
let
  buildFixes = _: {
    nixpkgs.overlays = [ inputs."rust-overlay".overlays.buildFixes ];
  };
in
{
  flake.modules.nixos.server = buildFixes;
  flake.modules.nixos.workstation = buildFixes;
}
