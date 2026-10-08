# LightCraft — the Lightroom equivalent: a photo catalog plus a non-destructive
# raw developer.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "lightcraft";
          version = "0.4.0";
          hash = "sha256-6/MxXgVN+1IPj4i/tjpUvP0xAKk22cuY7p6WQraZ1ug=";
          cargoHash = "sha256-Z6r3NGsYyE/bdTzuPFjUba6YsxCl9qieDrICeqFpo/A=";
          releaseDate = "2026-10-08";
          description = "Photo library and non-destructive raw developer";
        })
      ];
    };
}
