_: {
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      # Kensington SlimBlade Pro (047d:80d7): the top-right button is BTN_SIDE
      # ("back"), HID scancode 0x90004, on the trackball's mouse interface.
      #
      # Remap it to Super in-kernel via hwdb (EVIOCSKEYCODE) so Hyprland sees a
      # real held modifier. This relabels only that one button at report time --
      # no daemon, no EVIOCGRAB, no re-emit -- so the pointer path is untouched and
      # nothing is added to motion latency (the trackball is also used for gaming).
      #
      # 60-evdev.rules applies the hwdb "keyboard" builtin to any event* device
      # whose modalias matches (no ID_INPUT_KEY gate), so this reaches the mouse
      # node. hwdb is whitespace-sensitive: the match line takes no leading space
      # and the property line exactly one, hence the explicit "\n ".
      #
      # Kept after the move to the Ploopy Adept: the SlimBlade is the fallback if
      # the Adept fails, and the rule is keyed to 047d:80d7 so it cannot collide.
      services.udev.extraHwdb = "evdev:input:b0003v047Dp80D7*\n KEYBOARD_KEY_90004=leftmeta\n";

      # ----------------------------------------------------------------------
      # Ploopy Adept (5043:5c47) -- QMK firmware, flashed by hand
      # ----------------------------------------------------------------------
      #
      # The Adept runs QMK (keyboard name "ploopyco/madromys"), so its buttons are
      # remapped in firmware rather than with a hwdb rule like the SlimBlade above.
      # That is strictly better: the mapping follows the device to any machine, and
      # Super becomes a genuine KC_LGUI keycode instead of a relabelled mouse button.
      #
      # Nothing here is built by Nix. ./keymap.c and ./config.h are the source of
      # truth for what is on the device; the firmware is compiled and flashed
      # manually with the procedure below. Committed so a second unit can be made
      # identical, and so the numbers below are not re-derived from scratch.
      #
      # BUTTON MAPPING
      #
      # info.json's LAYOUT array is neither left-to-right nor matrix order. Its
      # order is TLL, TL, TR, TRR, BL, BR, mapping to matrix [0,1] [0,2] [0,3]
      # [0,4] [0,0] [0,5] respectively. Positions, viewed from above:
      #
      #     TLL      TL       TR       TRR      <- four small buttons, top arc
      #   Middle  DPI cycle  Scroll   Super        (TLL/TRR are the tall outer pair)
      #
      #     [ BL = Left ]  (ball)  [ BR = Right ]  <- the two large buttons
      #
      # Stock puts right-click on TRR and middle-click on BR, so the two large
      # buttons are left/middle. This mirrors the SlimBlade instead: large buttons
      # are left/right, middle moves to the tall left, Super to the tall right.
      #
      # DPI LADDER: { 400, 800, 1200, 1600 }, default 800
      #
      # The SlimBlade Pro's own four steps, cycled by its dedicated DPI button.
      # DPI_CONFIG persists the chosen index to EEPROM, so it survives replug but
      # NOT a keymap change that shortens the array -- ploopyco.c bounds-checks with
      # `> DPI_OPTION_SIZE` rather than `>=`, so a stored index equal to the array
      # length reads one past the end. Press the DPI button once after flashing if
      # the pointer speed is wrong; cycle_dpi() takes a modulo and self-corrects.
      #
      # DRAG-SCROLL DIVISOR: 113
      #
      # Measured, not guessed. The sensor reports ball-surface travel at CPI counts
      # per inch, and ploopyco.c accumulates y/DIVISOR, emitting a wheel click per
      # whole unit -- so clicks per inch of surface travel is exactly CPI/DIVISOR.
      # At stock DIVISOR 8 and 800 CPI that is 100 clicks/inch, which is frantic.
      #
      # Captured from a SlimBlade Pro with evdev: one full ball revolution produces
      # 48 REL_WHEEL detents (quarter turns gave 12 and 12; full turns read 41-48,
      # spread below 48 but never above it -- hand rotation falling short of a
      # complete turn, so 48 is the true value). That is 7.5 degrees per detent.
      # Its ball is 55mm, so one revolution is pi * 55 / 25.4 = 6.803 inches:
      #
      #   DIVISOR = CPI * inches-per-rev / detents-per-rev
      #           = 800 * 6.803 / 48
      #           = 113
      #
      # Check: 800/113 = 7.1 clicks/inch against the SlimBlade's 48/6.803 = 7.06.
      #
      # A FIXED divisor would make scroll rate depend on DPI, since the rate is
      # CPI/DIVISOR -- cycling to 1600 would scroll twice as fast, and the SlimBlade
      # match would hold at 800 CPI only. Avoided by making the divisor track DPI.
      # ploopyco.c uses the macro in expression position:
      #
      #   scroll_accumulated_v += (float)mouse_report.y / PLOOPY_DRAGSCROLL_DIVISOR_V;
      #
      # so it need not expand to a constant. ./config.h points it at a function in
      # ./keymap.c that scales with the live DPI (ploopyco.h exports both
      # keyboard_config and dpi_array), holding 7.08 clicks/inch at every step:
      #
      #   400 CPI -> divisor  56.5      1200 CPI -> divisor 169.5
      #   800 CPI -> divisor 113.0      1600 CPI -> divisor 226.0
      #
      # So the DPI button changes pointer speed only, as it does on the SlimBlade.
      # Cost is one array index, an int-to-float convert and a multiply per polled
      # report -- soft-float on the M0+, but negligible at ~1kHz. The prototype has
      # to be declared in config.h because ploopyco.c is what expands the macro.
      #
      # MOMENTARY drag-scroll is set explicitly rather than inherited. The unit
      # shipped behaving as momentary, but PLOOPY_DRAGSCROLL_MOMENTARY appears in
      # NO published Ploopy source -- not upstream QMK, not their qmk_firmware fork,
      # not their qmk_userspace_via repo, all of which leave madromys as a toggle.
      # The shipped binary also carried a third USB interface (VIA raw HID) and no
      # serial number, neither of which our build produces, so it came from a tree
      # that is not public. Inheriting the default would silently give a toggle.
      #
      # BUILDING
      #
      #   git clone --depth 1 https://github.com/qmk/qmk_firmware && cd qmk_firmware
      #   git submodule update --init --recursive --depth 1 \
      #     lib/chibios lib/chibios-contrib lib/pico-sdk lib/lufa lib/printf
      #   mkdir -p keyboards/ploopyco/madromys/keymaps/adept
      #   cp .../trackball/{keymap.c,config.h} keyboards/ploopyco/madromys/keymaps/adept/
      #   nix-shell -p qmk gcc-arm-embedded git python3 \
      #     --run "qmk compile -kb ploopyco/madromys -km adept"
      #
      # lib/lufa and lib/printf are NOT optional despite this being a ChibiOS
      # target: usb_main.c includes LUFA's HIDClassCommon.h and the compile dies
      # without it. `make git-submodule` handles this but needs qmk on PATH.
      #
      # Verify the result without flashing, since a build can succeed while the
      # keymap silently fails to apply -- search the .uf2 for the expected bytes:
      #   dpi_array          90012003 b0044006          (400, 800, 1200, 1600 LE)
      #   keymaps (matrix)   d100d300 007e017e e300d200 (BTN1 BTN3 DPI DRAG GUI BTN2)
      #
      # FLASHING: hold the LARGE LEFT button while plugging in. QMK's bootmagic
      # is enabled and defaults to matrix [0,0], which is that button, so the
      # RP2040 comes up as a USB mass-storage volume labelled RPI-RP2. Ploopy's
      # documented method -- shorting two vias on the PCB -- means opening the
      # shell and is not needed.
      #
      # If it will not enumerate, check `journalctl -k` before suspecting the
      # firmware. "low-speed" plus "device descriptor read/64, error -32" is a
      # cable fault: the RP2040 is a full-speed device, and low-speed detection
      # means the host is not seeing the pull-up where it belongs (a broken D+).
      # A failing port also power-cycles its whole hub, which takes down sibling
      # devices -- that is how a bad trackball cable presents as a broken keyboard.
      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "flash-adept";
          runtimeInputs = with pkgs; [
            coreutils
            util-linux
            gnugrep
          ];
          # Root is needed only to mount the bootloader volume; udisks2 is not
          # enabled on this host, so there is no user-level mount path. Success is
          # judged by the trackball re-enumerating, NOT by cp's exit status: the
          # board reboots the instant the UF2 lands, so the write often fails with
          # an I/O error even when it worked.
          text = ''
            FIRMWARE="''${1:-''${FIRMWARE:-}}"
            LABEL=/dev/disk/by-label/RPI-RP2
            PLOOPY_ID=5043:5c47
            BOOT_ID=2e8a:0003
            WAIT_SECS="''${WAIT_SECS:-90}"
            MOUNTDIR=""

            # Invoked by the EXIT trap below, which SC2329 cannot trace.
            # shellcheck disable=SC2329
            cleanup() {
              [ -n "$MOUNTDIR" ] || return 0
              if grep -q " $MOUNTDIR " /proc/mounts 2>/dev/null; then
                umount "$MOUNTDIR" 2>/dev/null || true
              fi
              rmdir "$MOUNTDIR" 2>/dev/null || true
            }
            trap cleanup EXIT

            die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

            # Read sysfs rather than calling lsusb, whose path is not guaranteed
            # to be on root's PATH under sudo.
            usb_present() {
              local want="''${1,,}" dir v p
              for dir in /sys/bus/usb/devices/*; do
                [ -r "$dir/idVendor" ] && [ -r "$dir/idProduct" ] || continue
                v=$(<"$dir/idVendor")
                p=$(<"$dir/idProduct")
                [ "''${v,,}:''${p,,}" = "$want" ] && return 0
              done
              return 1
            }

            [ -n "$FIRMWARE" ] || die "usage: flash-adept <firmware.uf2>"
            [ -f "$FIRMWARE" ] || die "firmware not found: $FIRMWARE"
            [ -s "$FIRMWARE" ] || die "firmware is empty: $FIRMWARE"
            # UF2 magicStart0 is 0x0A324655, little-endian on disk as "UF2\n".
            magic=$(head -c 4 "$FIRMWARE" | od -An -tx1 | tr -d ' \n')
            [ "$magic" = "5546320a" ] || die "not a UF2 (magic=$magic, want 5546320a)"
            echo "firmware OK: $FIRMWARE ($(stat -c %s "$FIRMWARE") bytes)"

            [ "$(id -u)" -eq 0 ] || die "must run as root: sudo flash-adept $FIRMWARE"

            if [ ! -e "$LABEL" ]; then
              echo ""
              echo "  >>> Hold the LARGE LEFT button and plug the trackball in now. <<<"
              echo ""
              for ((i = WAIT_SECS; i > 0; i--)); do
                [ -e "$LABEL" ] && break
                printf '\r  waiting %ds... ' "$i"
                sleep 1
              done
              printf '\n'
              [ -e "$LABEL" ] || die "bootloader never appeared -- hold the LARGE LEFT button while plugging in"
              sleep 1
            fi
            echo "bootloader volume present"

            MOUNTDIR=$(mktemp -d /tmp/rp2.XXXXXX) || die "could not create mount point"
            mount "$LABEL" "$MOUNTDIR" || die "mount failed: $LABEL"
            echo "mounted $LABEL at $MOUNTDIR"
            echo "writing firmware..."
            if cp "$FIRMWARE" "$MOUNTDIR"/ 2>/dev/null; then
              echo "  copy completed cleanly"
            else
              echo "  copy reported an error -- expected, the board reboots mid-write"
            fi
            sync 2>/dev/null || true
            sleep 2

            echo "waiting for the trackball to come back..."
            for ((i = 30; i > 0; i--)); do
              if usb_present "$PLOOPY_ID"; then
                printf '\n'
                echo "SUCCESS -- trackball re-enumerated as $PLOOPY_ID"
                exit 0
              fi
              printf '\r  waiting %ds... ' "$i"
              sleep 1
            done
            printf '\n'
            if usb_present "$BOOT_ID"; then
              die "still in bootloader ($BOOT_ID) -- the write did not take"
            fi
            die "nothing on the bus -- unplug and replug WITHOUT holding any button"
          '';
        })
      ];
    };
}
