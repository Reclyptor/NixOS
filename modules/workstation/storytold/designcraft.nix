# DesignCraft — the InDesign equivalent. Reads IDML, writes PDF and EPUB.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "designcraft";
          version = "0.12.0";
          hash = "sha256-gPG3Tb0vnmL3HO1iq5G8Rxg85UaVxf5iKJRCIuR3db8=";
          cargoHash = "sha256-WwLq9rKLTjvk5afjTYBdETIyEUoQjXUg/YGF7TAu8GA=";
          releaseDate = "2026-10-22";
          description = "Page layout for magazines, books and print documents";
          craftFontsRev = "abb83316d96aa59c1cf64784289e378fe9fa5695";
        })
      ];
    };
}
