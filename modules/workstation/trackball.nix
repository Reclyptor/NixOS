{ ... }: {
  flake.modules.nixos.workstation = { ... }: {
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
    services.udev.extraHwdb = "evdev:input:b0003v047Dp80D7*\n KEYBOARD_KEY_90004=leftmeta\n";
  };
}
