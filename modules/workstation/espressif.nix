_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    # Non-root serial access for flashing ESP32 boards (esptool, idf.py).
    #
    # Same 60-* constraint as via.nix: systemd consumes the `uaccess` tag in
    # 73-seat-late.rules, so the device must be tagged before then, and
    # services.udev.extraRules lands in 99-local.rules — too late.
    #
    # Preferred over adding the login user to `dialout`, which is defined once
    # in common/users.nix and would therefore also grant blanket serial access
    # on the five cluster nodes. This grants it on the workstation only, for
    # Espressif devices only, and applies on replug instead of at next login.
    #
    # Vendor 303a is Espressif's own USB Serial/JTAG (the S2/S3/C3 native USB
    # peripheral). Boards that use a UART bridge instead expose the bridge's
    # vendor — CP210x is 10c4, CH34x is 1a86 — and would need their own lines.
    services.udev.packages = [
      (pkgs.writeTextDir "etc/udev/rules.d/60-espressif.rules" ''
        SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", MODE="0660", TAG+="uaccess"
      '')
    ];
  };
}
