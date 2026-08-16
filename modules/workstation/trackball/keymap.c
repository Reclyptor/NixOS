#include QMK_KEYBOARD_H

// Argument order is the LAYOUT array in QMK's keyboards/ploopyco/madromys/info.json,
// which is NOT left-to-right and NOT matrix order:
//
//   TLL         TL          TR           TRR        BL         BR
//   tall-left   inner-left  inner-right  tall-right large-left large-right
//
// Stock is LAYOUT( MS_BTN4, MS_BTN5, DRAG_SCROLL, MS_BTN2, MS_BTN1, MS_BTN3 ),
// which puts right-click on the small tall-right button and middle-click on the
// large right one. This swaps that to match a Kensington SlimBlade Pro.
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [0] = LAYOUT( MS_BTN3, DPI_CONFIG, DRAG_SCROLL, KC_LGUI, MS_BTN1, MS_BTN2 )
};

// Drag-scroll rate is CPI/DIVISOR, so a constant divisor would scroll faster at
// higher DPI. Scaling the divisor with the active DPI holds the rate at 7.08
// clicks per inch across the whole ladder, leaving the DPI button to affect
// pointer speed only. 113 was measured against a SlimBlade Pro at 800 CPI; the
// ratio generalises it. config.h points the divisor macros here.
float adept_dragscroll_divisor(void) {
    return (float)dpi_array[keyboard_config.dpi_config] * (113.0f / 800.0f);
}
