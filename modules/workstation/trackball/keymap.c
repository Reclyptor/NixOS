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
