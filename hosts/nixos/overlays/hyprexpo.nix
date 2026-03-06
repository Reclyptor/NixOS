{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      hyprlandPlugins = prev.hyprlandPlugins // {
        hyprexpo = prev.hyprlandPlugins.hyprexpo.overrideAttrs (oldAttrs: {
          version = "0.54.1-unstable-2026-02-23";
          src = "${prev.fetchFromGitHub {
            owner = "hyprwm";
            repo = "hyprland-plugins";
            rev = "b85a56b9531013c79f2f3846fd6ee2ff014b8960";
            hash = "sha256-xwNa+1D8WPsDnJtUofDrtyDCZKZotbUymzV/R5s+M0I=";
          }}/hyprexpo";
        });
      };
    })
  ];
}
