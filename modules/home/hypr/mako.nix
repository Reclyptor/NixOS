{ ... }: {
  flake.modules.homeManager.base = { ... }: {
    # Mako notification daemon
    services.mako = {
      enable = true;
      settings = {
        anchor = "top-center";
        default-timeout = 5000;
        background-color = "#0C0F0C";
        text-color = "#A4C639";
        border-color = "#A4C639";
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
