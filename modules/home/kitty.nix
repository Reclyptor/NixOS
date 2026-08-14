_: {
  flake.modules.homeManager.base =
    {
      config,
      ...
    }:
    let
      inherit (config) palette;
    in
    {
      programs.kitty = {
        enable = true;

        font = {
          name = "FiraCode Nerd Font Mono";
          size = 12;
        };

        settings = {
          # Font settings
          bold_font = "auto";
          italic_font = "auto";
          bold_italic_font = "auto";

          # Window settings
          remember_window_size = false;
          initial_window_width = 950;
          initial_window_height = 500;
          window_padding_width = 10;
          hide_window_decorations = true;
          confirm_os_window_close = 0;

          # Opacity
          background_opacity = "0.7";
          dynamic_background_opacity = true;

          # Cursor
          cursor_blink_interval = "0.5";
          cursor_stop_blinking_after = 1;
          cursor_trail = 1;

          # Scrollback
          scrollback_lines = 2000;
          wheel_scroll_min_lines = 1;

          # Audio
          enable_audio_bell = false;

          # Basic colors - Android Green Theme
          foreground = "#${palette.accent}";
          background = "#${palette.backgroundDark}";
          selection_foreground = "#${palette.textDim}";
          selection_background = "#${palette.surfaceLight}";

          # Cursor colors
          cursor = "#656b47";
          cursor_text_color = "#${palette.surface}";

          # URL colors
          url_color = "#${palette.textSoft}";

          # Window border colors
          active_border_color = "#${palette.borderActive}";
          inactive_border_color = "#${palette.surface}";
          bell_border_color = "#435643";
          visual_bell_color = "none";

          # Titlebar colors
          wayland_titlebar_color = "#${palette.surfaceLight}";
          macos_titlebar_color = "#${palette.surfaceLight}";

          # Tab bar colors
          active_tab_foreground = "#fbfbf8";
          active_tab_background = "#${palette.surface}";
          inactive_tab_foreground = "#b2b5a1";
          inactive_tab_background = "#${palette.surfaceLight}";
          tab_bar_background = "#${palette.surfaceLight}";
          tab_bar_margin_color = "none";

          # Mark colors
          mark1_foreground = "#${palette.surface}";
          mark1_background = "#4f634f";
          mark2_foreground = "#${palette.surface}";
          mark2_background = "#90947a";
          mark3_foreground = "#${palette.surface}";
          mark3_background = "#818b4b";

          # The 16 ANSI colors
          # Black
          color0 = "#${palette.surface}";
          color8 = "#535f53";

          # Red
          color1 = "#5c705c";
          color9 = "#cbe25a";

          # Green
          color2 = "#${palette.accent}";
          color10 = "#${palette.surfaceLight}";

          # Yellow
          color3 = "#${palette.accentBright}";
          color11 = "#${palette.borderActive}";

          # Blue
          color4 = "#687d68";
          color12 = "#5e6e5e";

          # Magenta
          color5 = "#bfd454";
          color13 = "#${palette.textSoft}";

          # Cyan
          color6 = "#8fae8f";
          color14 = "#b1c44f";

          # White
          color7 = "#${palette.textDim}";
          color15 = "#f0fff0";
        };
      };
    };

}
