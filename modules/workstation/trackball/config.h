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

// Scroll rate, matched to a SlimBlade Pro by measurement -- see trackball.nix
// for the derivation. Higher divisor is slower; Ploopy's default is 8.0.
#define PLOOPY_DRAGSCROLL_DIVISOR_H 113.0
#define PLOOPY_DRAGSCROLL_DIVISOR_V 113.0
