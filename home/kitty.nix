{ config, pkgs, lib, ... }: {
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
      foreground = "#A4C639";
      background = "#0C0F0C";
      selection_foreground = "#A1B5A1";
      selection_background = "#353B35";
      
      # Cursor colors
      cursor = "#656b47";
      cursor_text_color = "#2a2d2a";
      
      # URL colors
      url_color = "#c8e4c8";
      
      # Window border colors
      active_border_color = "#485148";
      inactive_border_color = "#2a2d2a";
      bell_border_color = "#435643";
      visual_bell_color = "none";
      
      # Titlebar colors
      wayland_titlebar_color = "#353b35";
      macos_titlebar_color = "#353b35";
      
      # Tab bar colors
      active_tab_foreground = "#fbfbf8";
      active_tab_background = "#2a2d2a";
      inactive_tab_foreground = "#b2b5a1";
      inactive_tab_background = "#353b35";
      tab_bar_background = "#353b35";
      tab_bar_margin_color = "none";
      
      # Mark colors
      mark1_foreground = "#2a2d2a";
      mark1_background = "#4f634f";
      mark2_foreground = "#2a2d2a";
      mark2_background = "#90947a";
      mark3_foreground = "#2a2d2a";
      mark3_background = "#818b4b";
      
      # The 16 ANSI colors
      # Black
      color0 = "#2a2d2a";
      color8 = "#535f53";
      
      # Red
      color1 = "#5c705c";
      color9 = "#cbe25a";
      
      # Green
      color2 = "#A4C639";
      color10 = "#353b35";
      
      # Yellow
      color3 = "#e5fb79";
      color11 = "#485148";
      
      # Blue
      color4 = "#687d68";
      color12 = "#5e6e5e";
      
      # Magenta
      color5 = "#bfd454";
      color13 = "#c8e4c8";
      
      # Cyan
      color6 = "#8fae8f";
      color14 = "#b1c44f";
      
      # White
      color7 = "#a1b5a1";
      color15 = "#f0fff0";
    };
  };
}

