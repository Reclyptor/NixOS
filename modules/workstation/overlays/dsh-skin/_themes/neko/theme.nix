{
  id = "neko";
  title = "Neko · DeepSeek Harness";
  description = "Catgirls in a dark lounge: lime accents on near black";

  systemChromeColor = "#0C0F0C";

  # No theme.css. Assets plus the token table below are a complete skin — the
  # runtime's shared structure sheet positions every decoration node, and the
  # --dsw-* layer restyles the product UI. A stylesheet here would only be
  # elaboration beyond that, and this theme does not need any.

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
    brandSvg = ../maid-atelier/assets/brandSvg.svg;
  };

  # Decoration colours consumed by the shared structure sheet. Without these a
  # theme inherits the reference theme's gold glow, which would fight the
  # green.
  decoration = {
    "--skin-ornament-glow" = "rgba(164, 198, 57, 0.85)";
    "--skin-ornament-glow-strong" = "rgba(229, 251, 121, 0.90)";
    # A black drop shadow around a cutout reads as a dark halo, and against a
    # dark backdrop it buys nothing: there is no lighter surface for a shadow
    # to fall on. Off in dark, barely there in light.
    "--skin-figure-shadow" = "rgba(0, 0, 0, 0.12)";
    "--skin-figure-shadow-dark" = "rgba(0, 0, 0, 0)";
    "--skin-crest-shadow" = "rgba(0, 0, 0, 0.40)";

    # This theme's figures are already dark against a dark room, so the
    # reference theme's dark-scheme knock-back (brightness 0.84, saturate 0.92,
    # opacity 0.86) buries them. Keep them at full strength instead.
    "--skin-figure-brightness-dark" = "1.06";
    "--skin-figure-saturate-dark" = "1.05";
    "--skin-figure-opacity-chat" = "1";
    "--skin-figure-opacity-panel" = "0.96";

    # These cutouts carry less transparent margin than the reference art, so
    # the default gap leaves the left figure grazing the sidebar edge.
    "--skin-figure-left-gap" = "clamp(32px, 3.2vw, 80px)";

    # The remaining decoration shadows default to the reference theme's navy,
    # which halos against this palette exactly like the figure shadow did.
    "--skin-bow-shadow" = "rgba(0, 0, 0, 0.30)";
    "--skin-corner-shadow" = "rgba(0, 0, 0, 0.35)";
    "--skin-brand-shadow" = "rgba(0, 0, 0, 0.45)";
    "--skin-mascot-shadow" = "rgba(0, 0, 0, 0.22)";
    # The mascot reads on the dark rail because its art is light, not because a
    # filter lifts it: cranking brightness on near-black art buys nothing.
    "--skin-mascot-brightness" = "1";
    "--skin-mascot-contrast" = "1";
    # Sized and lit like the reference theme's: a small, full-colour figure
    # sitting low in the rail, not a large washed-out watermark. Its art is
    # portrait where the reference art is landscape, so it needs scaling down
    # to occupy the same share of the column.
    # This rail is near-opaque (0.985) so the mascot cannot read through it
    # from the default layer; it has to sit above the fill.
    # Both edges are one piece of artwork, so they must render at the same
    # height or the shared braid reads at two different scales.
    # One continuous band stretched across, never tiled: this theme's trim is a
    # single generated piece, and no tiling scheme survives contact with it.
    "--skin-top-trim-size" = "100% 51px";
    "--skin-trim-size-tall" = "100% 149px";
    "--skin-bottom-trim-size" = "100% 51px";
    "--skin-mascot-layer" = "3";
    "--skin-mascot-scale" = "0.62";
    "--skin-mascot-opacity" = "1";
    # The mascot is light art. That reads on the dark rail and disappears on
    # the light one, so the light scheme knocks it down and darkens it instead
    # of showing a white shape on a white surface.
    # Light scheme inverts the problem: light art on a light rail. Push it well
    # down into a dark silhouette and give it enough opacity to actually read,
    # rather than a pale ghost at low alpha.
    # Light scheme: the rail is pale and so is the mascot, so it needs
    # SEPARATION, not dimming. brightness() below 1 multiplies every channel
    # toward black and reads as a grey film laid over the art -- which is what
    # 0.62 was doing. Contrast deepens its own shadows instead, and a touch of
    # saturation keeps the greens present against the pale surface.
    "--skin-mascot-brightness-light" = "0.97";
    "--skin-mascot-contrast-light" = "1.22";
    "--skin-mascot-saturate-light" = "1.15";
    "--skin-mascot-opacity-light" = "1";

    # Base surface under the backdrop, and the title-bar wordmark ink.
    "--skin-body-color" = "#c8e4c8";
    "--skin-body-bg" = "#0C0F0C";
    "--skin-brand-ink" = "#c8e4c8";
    "--skin-brand-knockout" = "#0C0F0C";
  };

  # Mirrors modules/home/palette.nix so the harness matches the
  # rest of the desktop. The light column is a derived pale counterpart: the
  # config palette is dark-only, but dsh themes must stay legible in both
  # schemes, and `overrideTokens` rejects a single-value override for exactly
  # that reason.
  #
  # `bg-base` is transparent in both so the backdrop reads through.
  tokens = {
    "--dsw-alias-bg-base" = {
      light = "transparent";
      dark = "transparent";
    };
    "--dsw-alias-bg-layer-1" = {
      light = "rgba(244, 248, 238, 0.78)";
      dark = "rgba(20, 25, 20, 0.86)";
    };
    "--dsw-alias-bg-layer-2" = {
      light = "rgba(236, 243, 226, 0.86)";
      dark = "rgba(42, 45, 42, 0.88)";
    };
    "--dsw-alias-bg-layer-3" = {
      light = "rgba(228, 238, 214, 0.90)";
      dark = "rgba(53, 59, 53, 0.90)";
    };
    "--dsw-alias-bg-overlay" = {
      light = "rgba(248, 251, 244, 0.97)";
      dark = "rgba(12, 15, 12, 0.96)";
    };
    "--dsw-alias-border-l1" = {
      light = "rgba(75, 95, 30, 0.20)";
      dark = "rgba(164, 198, 57, 0.18)";
    };
    "--dsw-alias-border-l2" = {
      light = "rgba(75, 95, 30, 0.34)";
      dark = "rgba(164, 198, 57, 0.32)";
    };
    "--dsw-alias-border-l2-darkmode-thin" = {
      light = "rgba(75, 95, 30, 0.26)";
      dark = "rgba(164, 198, 57, 0.24)";
    };
    "--dsw-alias-border-l3" = {
      light = "rgba(122, 150, 40, 0.60)";
      dark = "rgba(229, 251, 121, 0.55)";
    };
    "--dsw-alias-brand-primary" = {
      light = "#5d7320";
      dark = "#a4c639";
    };
    "--dsw-alias-brand-text" = {
      light = "#1d2617";
      dark = "#c8e4c8";
    };
    "--dsw-alias-button-elevated-fill" = {
      light = "rgba(252, 254, 248, 0.90)";
      dark = "rgba(42, 45, 42, 0.94)";
    };
    "--dsw-alias-button-floating-fill" = {
      light = "rgba(252, 254, 248, 0.95)";
      dark = "rgba(53, 59, 53, 0.96)";
    };
    "--dsw-alias-button-floating-hover" = {
      light = "#e6efd6";
      dark = "#485148";
    };
    "--dsw-alias-button-info-fill" = {
      light = "#6f8c26";
      dark = "#a4c639";
    };
    "--dsw-alias-button-info-hover" = {
      light = "#5d7320";
      dark = "#e5fb79";
    };
    "--dsw-alias-interactive-bg-active" = {
      light = "rgba(164, 198, 57, 0.26)";
      dark = "rgba(164, 198, 57, 0.22)";
    };
    "--dsw-alias-interactive-bg-hover" = {
      light = "rgba(107, 116, 80, 0.12)";
      dark = "rgba(164, 198, 57, 0.12)";
    };
    "--dsw-alias-interactive-bg-hover-solid" = {
      light = "#e9f1dc";
      dark = "#2a2d2a";
    };
    "--dsw-alias-label-primary" = {
      light = "#1d2617";
      dark = "#c8e4c8";
    };
    "--dsw-alias-label-primary-bluish" = {
      light = "#2f3d24";
      dark = "#a1b5a1";
    };
    "--dsw-alias-label-secondary" = {
      light = "#4a5a38";
      dark = "#a1b5a1";
    };
    # measured 3.89:1 on the dark sidebar as palette `muted` (#6b7450), below
    # the 4.5 AA threshold. `textDim` clears it and stays on-palette.
    "--dsw-alias-label-tertiary" = {
      light = "#414a33";
      dark = "#a1b5a1";
    };
    "--dsw-alias-label-caption" = {
      light = "#4c5740";
      dark = "#a3b7a0";
    };
    "--dsw-alias-state-business-primary" = {
      light = "#6f8c26";
      dark = "#a4c639";
    };
    "--dsw-alias-state-business-tertiary" = {
      light = "#e4eed6";
      dark = "#2a2d2a";
    };
    "--dsw-shadow-lv2" = {
      light = "0 18px 54px rgba(30, 40, 20, 0.18), 0 2px 8px rgba(30, 40, 20, 0.12)";
      dark = "0 18px 58px rgba(0, 0, 0, 0.50), 0 2px 10px rgba(0, 0, 0, 0.40)";
    };
    "--dsw-specific-input-major" = {
      light = "rgba(252, 254, 248, 0.85)";
      dark = "rgba(20, 25, 20, 0.88)";
    };
    "--dsw-specific-selector" = {
      light = "rgba(232, 240, 220, 0.90)";
      dark = "rgba(42, 45, 42, 0.90)";
    };
    # The rail follows the scheme. An earlier revision forced it dark in both,
    # on the claim that dsh paints sidebar labels with the inverted tokens —
    # that was wrong. Read off the live page, those labels compute to
    # `label-primary` (#1d2617) and `label-primary-inverted` is plain white and
    # unused there, so a dark rail in the light scheme put near-black text on a
    # near-black surface at 1.09:1.
    # Near-opaque on purpose. At 0.92 the rail composited over the backdrop
    # PHOTOGRAPH, so every label sat on whatever pixels happened to be behind
    # it — a muddy olive in light scheme — and its real contrast had nothing to
    # do with the computed token pair. Text needs a stable surface, so the rail
    # stops being a window.
    "--dsw-specific-sidebar-fill" = {
      light = "rgba(240, 246, 231, 0.985)";
      dark = "rgba(11, 14, 11, 0.985)";
    };
  };
}
