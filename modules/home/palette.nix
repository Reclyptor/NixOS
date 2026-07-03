{ ... }: {
  # Single source of truth for the "Android Green" scheme used across kitty,
  # hyprland, hyprlock, waybar, mako, fuzzel, and oh-my-posh.
  #
  # Values are bare RRGGBB hex (no leading #) so every notation can be built
  # from one definition: "#${accent}", "rgba(${accent}FF)", "${accent}FF".
  # The *Rgb variants exist for hyprlock's rgb(r, g, b) syntax — keep them in
  # sync with their hex twin when retheming.
  flake.modules.homeManager.base = { lib, ... }: {
    options.palette = {
      accent = lib.mkOption {
        type = lib.types.str;
        default = "A4C639";
        description = "Primary accent (Android Green).";
      };

      accentRgb = lib.mkOption {
        type = lib.types.str;
        default = "164, 198, 57";
        description = "accent as decimal r, g, b.";
      };

      accentBright = lib.mkOption {
        type = lib.types.str;
        default = "e5fb79";
        description = "Bright accent highlight (yellow-green).";
      };

      background = lib.mkOption {
        type = lib.types.str;
        default = "141914";
        description = "Main dark background.";
      };

      backgroundRgb = lib.mkOption {
        type = lib.types.str;
        default = "20, 25, 20";
        description = "background as decimal r, g, b.";
      };

      backgroundDark = lib.mkOption {
        type = lib.types.str;
        default = "0C0F0C";
        description = "Deepest background (terminal, lock screen outer).";
      };

      backgroundDarkRgb = lib.mkOption {
        type = lib.types.str;
        default = "12, 15, 12";
        description = "backgroundDark as decimal r, g, b.";
      };

      surface = lib.mkOption {
        type = lib.types.str;
        default = "2a2d2a";
        description = "Raised surfaces: active tabs, cursor text, marks.";
      };

      surfaceLight = lib.mkOption {
        type = lib.types.str;
        default = "353b35";
        description = "Lighter surfaces: inactive tabs, titlebars, selections.";
      };

      muted = lib.mkOption {
        type = lib.types.str;
        default = "6b7450";
        description = "Muted olive for secondary text and inactive elements.";
      };

      textSoft = lib.mkOption {
        type = lib.types.str;
        default = "c8e4c8";
        description = "Soft pale-green text (URLs, highlights).";
      };

      borderActive = lib.mkOption {
        type = lib.types.str;
        default = "485148";
        description = "Active border gray-green.";
      };
    };
  };
}
