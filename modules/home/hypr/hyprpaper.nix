{ ... }: {
  flake.modules.homeManager.base = { config, ... }: {
    xdg.configFile."hypr/hyprpaper.conf".text = ''
      ipc = true
      splash = false

      wallpaper {
          monitor =
          path = ${config.home.homeDirectory}/.config/wallpapers/default.jpg
          fit_mode = cover
      }
    '';

    # Copy wallpaper from Nix configuration to home directory
    home.file.".config/wallpapers/default.jpg".source = ../../../wallpapers/default.jpg;
  };
}
