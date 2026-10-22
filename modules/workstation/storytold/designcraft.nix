# DesignCraft — the InDesign equivalent. Reads IDML, writes PDF and EPUB.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "designcraft";
          version = "0.9.0";
          hash = "sha256-IL5kXdkFG1CiIuh3dWTphFu5EPHeSrg2eQ8N9dFNqkQ=";
          cargoHash = "sha256-pt/8PkH2c9IKFRgNIKkEUyUMca/glpEoo5CjgM3VVyU=";
          releaseDate = "2026-10-18";
          description = "Page layout for magazines, books and print documents";
          craftFontsRev = "abb83316d96aa59c1cf64784289e378fe9fa5695";
        })
      ];
    };
}
