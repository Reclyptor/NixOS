{ ... }: {
  flake.modules.homeManager.base = { ... }: {
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
          background = "0C0F0CF2";
          text = "A4C639FF";
          prompt = "6b7450FF";
          input = "A4C639FF";
          match = "A4C639FF";
          selection = "A4C63933";
          selection-text = "A4C639FF";
          selection-match = "A4C639FF";
          border = "A4C639FF";
        };
        border = {
          width = 2;
          radius = 8;
        };
      };
    };
  };
}
