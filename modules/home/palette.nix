_: {
  # Single source of truth for the "Android Green" scheme used across kitty,
  # hyprland, hyprlock, waybar, mako, fuzzel, and oh-my-posh.
  #
  # Values are bare RRGGBB hex (no leading #) so every notation can be built
  # from one definition: "#${accent}", "rgba(${accent}FF)", "${accent}FF".
  # The *Rgb variants exist for hyprlock's rgb(r, g, b) syntax — keep them in
  # sync with their hex twin when retheming.
  #
  # Two layers live here. The STRUCTURAL tokens (background, surface, border,
  # text) describe where a thing sits in the stack. The SEMANTIC tokens
  # (error, warning, info, special, detail) describe what a thing means, and
  # exist because the terminal needs sixteen slots that carry meaning rather
  # than sixteen shades of the accent. Never spend a structural token on text:
  # surfaces are built to be low-contrast, and a text slot that reads as a
  # surface is an invisible one.
  flake.modules.homeManager.base = { config, lib, ... }: {
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

      textDim = lib.mkOption {
        type = lib.types.str;
        default = "a1b5a1";
        description = "Dim gray-green text (terminal white slot, selections).";
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

      urgent = lib.mkOption {
        type = lib.types.str;
        default = config.palette.error;
        description = "States that must not blend in, like a live screen recording. Follows error unless overridden.";
      };

      # Semantic layer. Hues are spaced for distinguishability, then pulled
      # down in chroma so none of them outshouts the accent: accent sits at
      # L* 75.2 / C* 70.1, the loudest of anything defined here.
      error = lib.mkOption {
        type = lib.types.str;
        default = "d94f4f";
        description = "Failure, deletion, the red the scheme never had.";
      };

      errorBright = lib.mkOption {
        type = lib.types.str;
        default = "f0796b";
        description = "Bright error — what most tools reach for on a hard failure.";
      };

      warning = lib.mkOption {
        type = lib.types.str;
        default = "d9a93c";
        description = "Caution, degraded state, skipped work.";
      };

      warningBright = lib.mkOption {
        type = lib.types.str;
        default = "f2cc5e";
        description = "Bright warning.";
      };

      info = lib.mkOption {
        type = lib.types.str;
        default = "5f93c9";
        description = "Neutral structure: gutters, line numbers, directories.";
      };

      infoBright = lib.mkOption {
        type = lib.types.str;
        default = "86b3e3";
        description = "Bright info.";
      };

      special = lib.mkOption {
        type = lib.types.str;
        default = "b06fbe";
        description = "Set apart without alarm: keywords, constants.";
      };

      specialBright = lib.mkOption {
        type = lib.types.str;
        default = "d49ada";
        description = "Bright special.";
      };

      detail = lib.mkOption {
        type = lib.types.str;
        default = "4fb09f";
        description = "Supporting detail: hunk headers, symlinks, notes.";
      };

      detailBright = lib.mkOption {
        type = lib.types.str;
        default = "7fd3c2";
        description = "Bright detail.";
      };

      accentDim = lib.mkOption {
        type = lib.types.str;
        default = "667a66";
        description = "Dimmed text that must still be readable: comments, timestamps.";
      };

      greenBright = lib.mkOption {
        type = lib.types.str;
        default = "c6e85c";
        description = "Accent lifted for the bright green slot.";
      };

      textBright = lib.mkOption {
        type = lib.types.str;
        default = "f0fff0";
        description = "Brightest text, near-white with a green cast.";
      };
    };
  };
}
