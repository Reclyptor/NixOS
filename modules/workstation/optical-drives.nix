_: {
  # This machine has one USB Blu-ray drive. It was not attached when the
  # inventory was taken (no /dev/sr*, no matching serial under /dev/disk/by-id),
  # so its serial is not recorded yet — leaving the list empty is correct until
  # it is. The four serials previously listed here all belong to styxeon's
  # drives, so those rules never matched anything on this host.
  #
  # To fill in: attach the drive and read
  #   udevadm info --query=property --name=/dev/sr0 | grep ID_SERIAL_SHORT
  # then add { serial = "..."; } below (name defaults to bluray-<serial>; set
  # `name` explicitly for a positional name, and `sg = true` if a tool needs the
  # SCSI-generic node).
  flake.modules.nixos.workstation = _: {
    opticalDrives = [ ];
  };
}
