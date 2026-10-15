# DesignCraft — the InDesign equivalent. Reads IDML, writes PDF and EPUB.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "designcraft";
          version = "0.8.0";
          hash = "sha256-Ze5eAiIZkL1ccTFA6dNZ9TG6/SxuIb9c8/v0v0dwX2Y=";
          cargoHash = "sha256-IKiZRTrYovE8ofm4Dg/u8wRBkHHbxAMECUy5qzCBnjc=";
          releaseDate = "2026-10-14";
          description = "Page layout for magazines, books and print documents";
          craftFontsRev = "abb83316d96aa59c1cf64784289e378fe9fa5695";
        })
      ];
    };
}
