{ ... }: {
  flake.modules.homeManager.base = { config, ... }: let palette = config.palette; in {
    # Mako notification daemon
    services.mako = {
      enable = true;
      settings = {
        anchor = "top-center";
        default-timeout = 5000;
        background-color = "#${palette.backgroundDark}";
        text-color = "#${palette.accent}";
        border-color = "#${palette.accent}";
        border-radius = 10;
        border-size = 2;
        width = 300;
        height = 100;
        padding = "10";
        margin = "10";
      };
    };
  };
}
