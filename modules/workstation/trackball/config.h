#pragma once

// The SlimBlade Pro's four DPI steps, cycled by DPI_CONFIG and persisted to
// EEPROM. Ploopy's own default ladder is { 600, 900, 1200, 1600, 2400 }.
#define PLOOPY_DPI_OPTIONS \
    { 400, 800, 1200, 1600 }
#define PLOOPY_DPI_DEFAULT 1

// Hold to scroll rather than toggle. Set explicitly: upstream madromys leaves
// this undefined, which means toggle, and a toggle carries invisible state --
// come back to the desk and you cannot tell whether the ball scrolls or moves.
#define PLOOPY_DRAGSCROLL_MOMENTARY

// Flip vertical scroll. Touches mouse_report.v only; horizontal is unchanged.
#define PLOOPY_DRAGSCROLL_INVERT

// ploopyco.c uses these macros in expression position, so they need not be
// constants. Routing them through a function keeps the scroll rate fixed as the
// DPI changes -- see adept_dragscroll_divisor() in keymap.c and the derivation
// in trackball.nix. The prototype lives here because ploopyco.c, not keymap.c,
// is the translation unit that expands the macro.
#ifndef __ASSEMBLER__
float adept_dragscroll_divisor(void);
#endif
#define PLOOPY_DRAGSCROLL_DIVISOR_H adept_dragscroll_divisor()
#define PLOOPY_DRAGSCROLL_DIVISOR_V adept_dragscroll_divisor()
