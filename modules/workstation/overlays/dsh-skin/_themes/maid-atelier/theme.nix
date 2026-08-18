{
  id = "maid-atelier";
  title = "Abyssal Maid Atelier · DeepSeek Harness";
  description = "Abyssal maid atelier: twin-maid backdrop, deep-sea navy chrome and soft gold";

  # The palace night blue, so the OS window chrome meets the backdrop instead
  # of framing it in stock DeepSeek grey.
  systemChromeColor = "#0b193f";

  css = ./theme.css;

  art = {
    backdropLight = ./assets/backdropLight.webp;
    backdropDark = ./assets/backdropDark.webp;
    characterLeft = ./assets/characterLeft.webp;
    characterRight = ./assets/characterRight.webp;
    sidebarMascot = ./assets/sidebarMascot.webp;
    sidebarSwag = ./assets/sidebarSwag.webp;
    sidebarCorner = ./assets/sidebarCorner.webp;
    topTrimTile = ./assets/topTrimTile.webp;
    bottomTrimTile = ./assets/bottomTrimTile.webp;
    bottomCrest = ./assets/bottomCrest.webp;
    composerFrame = ./assets/composerFrame.webp;
    settingsFrame = ./assets/settingsFrame.webp;
    workspaceShield = ./assets/workspaceShield.webp;
    workspaceRibbon = ./assets/workspaceRibbon.webp;
    accentBow = ./assets/accentBow.webp;
    newSession = ./assets/newSession.webp;
    favicon = ./assets/favicon.webp;
    brandSvg = ./assets/brandSvg.svg;
  };

  # The palette the artwork was drawn against, carried over verbatim from the
  # upstream skin's own light/dark blocks so the chrome meets the art instead
  # of approximating it. Applied through `overrideTokens`, which stacks over
  # whichever base palette the user has persisted.
  #
  # `bg-base` is transparent on purpose: an opaque base would paint over the
  # backdrop this theme exists to show.
  tokens = {
    "--dsw-alias-bg-base" = {
      light = "transparent";
      dark = "transparent";
    };
    "--dsw-alias-bg-layer-1" = {
      light = "rgba(248, 250, 255, 0.72)";
      dark = "rgba(18, 31, 67, 0.9)";
    };
    "--dsw-alias-bg-layer-2" = {
      light = "rgba(235, 240, 250, 0.84)";
      dark = "rgba(24, 40, 80, 0.92)";
    };
    "--dsw-alias-bg-layer-3" = {
      light = "rgba(224, 231, 246, 0.88)";
      dark = "rgba(32, 49, 91, 0.94)";
    };
    "--dsw-alias-bg-overlay" = {
      light = "rgba(248, 250, 255, 0.96)";
      dark = "rgba(13, 25, 59, 0.97)";
    };
    "--dsw-alias-border-l1" = {
      light = "rgba(71, 91, 145, 0.18)";
      dark = "rgba(151, 169, 216, 0.2)";
    };
    "--dsw-alias-border-l2" = {
      light = "rgba(71, 91, 145, 0.3)";
      dark = "rgba(151, 169, 216, 0.34)";
    };
    "--dsw-alias-border-l2-darkmode-thin" = {
      light = "rgba(71, 91, 145, 0.25)";
      dark = "rgba(151, 169, 216, 0.3)";
    };
    "--dsw-alias-border-l3" = {
      light = "rgba(197, 164, 104, 0.64)";
      dark = "rgba(211, 180, 119, 0.66)";
    };
    "--dsw-alias-brand-primary" = {
      light = "#526aa8";
      dark = "#9bb0e1";
    };
    "--dsw-alias-brand-text" = {
      light = "#172347";
      dark = "#e7ecf7";
    };
    "--dsw-alias-button-elevated-fill" = {
      light = "rgba(255, 253, 248, 0.88)";
      dark = "rgba(28, 44, 84, 0.94)";
    };
    "--dsw-alias-button-floating-fill" = {
      light = "rgba(255, 253, 248, 0.94)";
      dark = "rgba(31, 49, 92, 0.96)";
    };
    "--dsw-alias-button-floating-hover" = {
      light = "#ece6d8";
      dark = "#354d88";
    };
    "--dsw-alias-button-info-fill" = {
      light = "#536eae";
      dark = "#8ca4dc";
    };
    "--dsw-alias-button-info-hover" = {
      light = "#405a99";
      dark = "#a3b7e5";
    };
    "--dsw-alias-interactive-bg-active" = {
      light = "rgba(197, 164, 104, 0.24)";
      dark = "rgba(211, 180, 119, 0.24)";
    };
    "--dsw-alias-interactive-bg-hover" = {
      light = "rgba(103, 126, 183, 0.12)";
      dark = "rgba(164, 183, 229, 0.14)";
    };
    "--dsw-alias-interactive-bg-hover-solid" = {
      light = "#e2e8f5";
      dark = "#293f78";
    };
    "--dsw-alias-label-caption" = {
      light = "#8a94aa";
      dark = "#7f90b4";
    };
    "--dsw-alias-label-primary" = {
      light = "#172347";
      dark = "#e7ecf7";
    };
    "--dsw-alias-label-primary-bluish" = {
      light = "#243866";
      dark = "#d5dff3";
    };
    "--dsw-alias-label-secondary" = {
      light = "#4d5d7f";
      dark = "#bdc9e3";
    };
    "--dsw-alias-label-tertiary" = {
      light = "#6f7c99";
      dark = "#96a6c9";
    };
    "--dsw-alias-state-business-primary" = {
      light = "#536eae";
      dark = "#9bb0e1";
    };
    "--dsw-alias-state-business-tertiary" = {
      light = "#e1e7f5";
      dark = "#293d73";
    };
    "--dsw-shadow-lv2" = {
      light = "var(--maid-shadow)";
      dark = "var(--maid-shadow)";
    };
    "--dsw-specific-input-major" = {
      light = "rgba(255, 253, 248, 0.82)";
      dark = "rgba(17, 30, 66, 0.88)";
    };
    "--dsw-specific-selector" = {
      light = "rgba(226, 232, 246, 0.9)";
      dark = "rgba(45, 64, 111, 0.9)";
    };
    "--dsw-specific-sidebar-fill" = {
      light = "rgba(11, 25, 66, 0.88)";
      dark = "rgba(5, 13, 40, 0.9)";
    };
  };
}
