/**
 * The single contract between the theme-agnostic engine and one theme.
 *
 * Every theme-specific value the engine consumes appears here. Adding a theme
 * means satisfying this interface — palette table plus art slots — and never
 * editing the engine. `manifest.generated.ts` is written by the Nix build from
 * `_themes/<id>/theme.nix`; the asset fields arrive as data URIs because
 * esbuild inlines them through its `dataurl` loader.
 */

/**
 * One palette value, in both base palettes. Both modes are mandatory — dsh's
 * own `overrideTokens` rejects a bare string for exactly this reason: a
 * single-mode override goes illegible the moment the user flips schemes.
 */
export interface ThemeTokenModes {
  readonly light: string
  readonly dark: string
}

/**
 * The art slots one theme supplies, mirroring the decoration set the engine
 * knows how to place. Each value is a data URI except `brandSvg`, which is
 * inline SVG markup for the title-bar wordmark.
 */
export interface ThemeArt {
  /** Full-viewport backdrop used while the light base palette is active. */
  readonly backdropLight: string
  /** Full-viewport backdrop used while `body[data-ds-dark-theme]` is set. */
  readonly backdropDark: string
  /** Character cutout anchored to the left of the conversation stage. */
  readonly characterLeft: string
  /** Character cutout anchored to the right of the conversation stage. */
  readonly characterRight: string
  /** Small figure seated at the top of the sidebar column. */
  readonly sidebarMascot: string
  /** Drape hung under the sidebar header. */
  readonly sidebarSwag: string
  /** Corner ornament, mirrored into all four sidebar corners. */
  readonly sidebarCorner: string
  /** Horizontally tiled trim along the top edge. */
  readonly topTrimTile: string
  /** Horizontally tiled trim along the bottom edge. */
  readonly bottomTrimTile: string
  /** Centred crest seated on the bottom trim. */
  readonly bottomCrest: string
  /** Frame drawn around the message composer. */
  readonly composerFrame: string
  /** Frame drawn around the settings overlay. */
  readonly settingsFrame: string
  /** Crest marking the active workspace tab. */
  readonly workspaceShield: string
  /** Ribbon trailing the workspace tab strip. */
  readonly workspaceRibbon: string
  /** Accent flourish reused by small chrome details. */
  readonly accentBow: string
  /** Ornament seated on the new-session control. */
  readonly newSession: string
  /** Browser tab icon. */
  readonly favicon: string
  /** Inline SVG wordmark placed at the left of the frameless title bar. */
  readonly brandSvg: string
}

/** One theme, fully described. */
export interface ThemeManifest {
  /** Theme id, e.g. `placeholder`. Also the diagnostics label. */
  readonly id: string
  /** Full package name; doubles as the `overrideTokens` layer source. */
  readonly packageName: string
  /** Value written to `document.title` while the skin is applied. */
  readonly title: string
  /** Value forced into `<meta name="theme-color">` for OS window chrome. */
  readonly systemChromeColor: string
  /**
   * `--dsw-*` overrides stacked over the active base theme: the palette table
   * the theme declares, under the engine's typography layer.
   */
  readonly tokens: Readonly<Record<string, ThemeTokenModes>>
  /** Generated art, inlined at build time. */
  readonly art: ThemeArt
  /**
   * Optional per-theme stylesheet, injected after the shared structure sheet.
   * A theme needs none: assets plus `tokens` already render a complete skin.
   * Use it only to restyle the product's own UI beyond the token layer.
   */
  readonly css: string

  /**
   * Optional decoration colour overrides consumed by the shared structure
   * sheet (`--skin-ornament-glow`, `--skin-figure-shadow`, ...). Omitted keys
   * fall back to the values baked into structure.css.
   */
  readonly decoration: Readonly<Record<string, string>>
}
