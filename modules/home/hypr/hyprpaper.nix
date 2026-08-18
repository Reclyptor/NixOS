_: {
  flake.modules.homeManager.base =
    { config, ... }:
    {
      services.hyprpaper = {
        enable = true;

        settings = {
          ipc = true;
          splash = false;

          wallpaper = [
            {
              monitor = "";
              path = "${config.home.homeDirectory}/.config/wallpapers/default.png";
              fit_mode = "cover";
            }
          ];
        };
      };

      # Copy wallpaper from Nix configuration to home directory
      home.file.".config/wallpapers/default.png".source = ../../../wallpapers/default.png;
    };
}
