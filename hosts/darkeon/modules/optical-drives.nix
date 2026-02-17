{ config, pkgs, ... }: {
  # TODO: Update serial numbers for optical drives attached to darkeon
  # Run: udevadm info --query=all --name=/dev/srX | grep ID_SERIAL_SHORT
  services.udev.extraRules = ''
  '';
}
