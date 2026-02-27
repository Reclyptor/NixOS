{ ... }: {
  # Ignore Sony touchpad input nodes (USB/Bluetooth) so the DualSense touchpad
  # no longer acts like a mouse/scroll wheel.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_VENDOR_ID}=="054c", ENV{ID_INPUT_TOUCHPAD}=="1", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';
}
