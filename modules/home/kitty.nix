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

          # The 16 ANSI colors.
          #
          # These are the only sixteen colors a terminal program can ask for
          # by name, so each one has to carry its meaning on its own. They
          # resolve from the palette's semantic layer, never from structural
          # tokens — a surface color in a text slot is an unreadable one.
          #
          # Calibration held here: every chromatic slot clears 4.5:1 against
          # the background, every bright slot is strictly brighter than its
          # normal, and no two slots in a row sit closer than ΔE 25. The
          # accent stays the loudest hue on screen.

          # Black
          color0 = "#${palette.surface}";
          color8 = "#${palette.accentDim}";

          # Red
          color1 = "#${palette.error}";
          color9 = "#${palette.errorBright}";

          # Green
          color2 = "#${palette.accent}";
          color10 = "#${palette.greenBright}";

          # Yellow
          color3 = "#${palette.warning}";
          color11 = "#${palette.warningBright}";

          # Blue
          color4 = "#${palette.info}";
          color12 = "#${palette.infoBright}";

          # Magenta
          color5 = "#${palette.special}";
          color13 = "#${palette.specialBright}";

          # Cyan
          color6 = "#${palette.detail}";
          color14 = "#${palette.detailBright}";

          # White
          color7 = "#${palette.textDim}";
          color15 = "#${palette.textBright}";
        };
      };
    };

}
