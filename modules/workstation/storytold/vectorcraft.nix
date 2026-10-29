# VectorCraft — the Illustrator equivalent. Reads and writes SVG and PDF.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "vectorcraft";
          version = "0.18.0";
          hash = "sha256-vohd9enSBgOwXtOMVOAE3SJ/GRrRsp52l1X7O0n7bd0=";
          cargoHash = "sha256-cfABh/4Wx8pA2nMJZ9/BvbQvYADmnb+B1Ws82EP3HKY=";
          releaseDate = "2026-10-28";
          description = "Vector graphics editor for illustrations, SVG and PDF";
          craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";
        })
      ];
    };
}
