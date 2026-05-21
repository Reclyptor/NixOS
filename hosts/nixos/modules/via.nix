{ pkgs, ... }: {
  # Non-root HID access for configuring the Vortex Core Plus keyboard with VIA
  # (usevia.app, over WebHID in the browser).
  #
  # This has to be a 60-* rules file: systemd consumes the `uaccess` tag in
  # 73-seat-late.rules, so the device must be tagged before then.
  # services.udev.extraRules lands in 99-local.rules and tags it too late,
  # leaving the ACL unapplied. Vendor 320f covers both the wired (5055) and
  # 2.4GHz dongle (5088) interfaces.
  services.udev.packages = [
    (pkgs.writeTextDir "etc/udev/rules.d/60-via.rules" ''
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="320f", MODE="0660", TAG+="uaccess"
    '')
  ];
}
