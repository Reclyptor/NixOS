/**
 * Ambient types for the non-JS imports the Nix build feeds through esbuild's
 * loaders. The loader mapping in `dsh-skin.nix` is the authority; these
 * declarations exist so `tsc --noEmit` agrees with it.
 */

/** Raster art, inlined by the `dataurl` loader. */
declare module '*.webp' {
  const dataUri: string
  export default dataUri
}

/** Icon art, inlined by the `dataurl` loader. */
declare module '*.png' {
  const dataUri: string
  export default dataUri
}

/** Inline SVG markup, read by the `text` loader. */
declare module '*.svg' {
  const markup: string
  export default markup
}

/** The theme stylesheet, read by the `text` loader. */
declare module '*.css' {
  const stylesheet: string
  export default stylesheet
}
