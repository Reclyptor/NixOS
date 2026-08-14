_: {
  flake.modules.homeManager.base =
    { config, ... }:
    let
      inherit (config) palette;
    in
    {
      # Hyprlock configuration
      programs.hyprlock = {
        enable = true;
        settings = {
          general = {
            disable_loading_bar = true;
            grace = 0;
            hide_cursor = true;
            no_fade_in = false;
          };

          background = [
            {
              path = "screenshot";
              blur_passes = 3;
              blur_size = 8;
            }
          ];

          input-field = [
            {
              size = "200, 50";
              position = "0, -80";
              monitor = "";
              dots_center = true;
              fade_on_empty = false;
              font_color = "rgb(${palette.accentRgb})";
              inner_color = "rgb(${palette.backgroundRgb})";
              outer_color = "rgb(${palette.backgroundDarkRgb})";
              outline_thickness = 5;
              placeholder_text = "Password...";
              shadow_passes = 2;
            }
          ];
        };
      };
    };
}
