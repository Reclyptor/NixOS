{ ... }: {
  flake.modules.homeManager.base = { config, ... }: let palette = config.palette; in {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          prompt = "\"  \"";
          layer = "overlay";
          width = 35;
          lines = 10;
          horizontal-pad = 12;
          vertical-pad = 10;
          inner-pad = 8;
        };
        colors = {
          background = "${palette.backgroundDark}F2";
          text = "${palette.accent}FF";
          prompt = "${palette.muted}FF";
          input = "${palette.accent}FF";
          match = "${palette.accent}FF";
          selection = "${palette.accent}33";
          selection-text = "${palette.accent}FF";
          selection-match = "${palette.accent}FF";
          border = "${palette.accent}FF";
        };
        border = {
          width = 2;
          radius = 8;
        };
      };
    };
  };
}
