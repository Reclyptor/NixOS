# DesignCraft — the InDesign equivalent. Reads IDML, writes PDF and EPUB.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "designcraft";
          version = "0.4.0";
          hash = "sha256-rissTTWbEe7ugm030syYmoquNVf9PNUPn0fdd4Eo02k=";
          cargoHash = "sha256-GbQHf8GVm8nB8fcGcIDyhWJY/um9W4y1KRryUd574ws=";
          releaseDate = "2026-10-08";
          description = "Page layout for magazines, books and print documents";
        })
      ];
    };
}
