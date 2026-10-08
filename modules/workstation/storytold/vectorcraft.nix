# VectorCraft — the Illustrator equivalent. Reads and writes SVG and PDF.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "vectorcraft";
          version = "0.11.0";
          hash = "sha256-kATUMg2Bo8karh4swMByAg7E3BGg8lrpppEh3VT+oZ0=";
          cargoHash = "sha256-rehAo3VB8gqPjRuOGohbqJmMtZjh5xkK4UBBEJFRa/o=";
          releaseDate = "2026-10-14";
          description = "Vector graphics editor for illustrations, SVG and PDF";
        })
      ];
    };
}
